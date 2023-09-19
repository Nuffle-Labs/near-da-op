package derive

/*
#cgo LDFLAGS: -L../../../lib -lnear_da_op_rpc_sys -lssl -lcrypto -lm
#include "../../../lib/libnear-da-op-rpc.h"
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"errors"
	"fmt"
	"io"
	"reflect"
	"unsafe"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/ethereum-optimism/optimism/op-celestia/celestia"
	"github.com/ethereum-optimism/optimism/op-node/eth"
	"github.com/ethereum-optimism/optimism/op-node/rollup"
)

type DataIter interface {
	Next(ctx context.Context) (eth.Data, error)
}

type L1TransactionFetcher interface {
	InfoAndTxsByHash(ctx context.Context, hash common.Hash) (eth.BlockInfo, types.Transactions, error)
}

// DataSourceFactory readers raw transactions from a given block & then filters for
// batch submitter transactions.
// This is not a stage in the pipeline, but a wrapper for another stage in the pipeline
type DataSourceFactory struct {
	log     log.Logger
	cfg     *rollup.Config
	daCfg   *rollup.DAConfig
	fetcher L1TransactionFetcher
}

func NewDataSourceFactory(log log.Logger, cfg *rollup.Config, daCfg *rollup.DAConfig, fetcher L1TransactionFetcher) *DataSourceFactory {
	return &DataSourceFactory{log: log, cfg: cfg, daCfg: daCfg, fetcher: fetcher}
}

// OpenData returns a DataIter. This struct implements the `Next` function.
func (ds *DataSourceFactory) OpenData(ctx context.Context, id eth.BlockID, batcherAddr common.Address) (DataIter, error) {
	return NewDataSource(ctx, ds.log, ds.cfg, ds.daCfg, ds.fetcher, id, batcherAddr)
}

// DataSource is a fault tolerant approach to fetching data.
// The constructor will never fail & it will instead re-attempt the fetcher
// at a later point.
type DataSource struct {
	// Internal state + data
	open bool
	data []eth.Data
	// Required to re-attempt fetching
	id      eth.BlockID
	cfg     *rollup.Config // TODO: `DataFromEVMTransactions` should probably not take the full config
	daCfg   *rollup.DAConfig
	fetcher L1TransactionFetcher
	log     log.Logger

	batcherAddr common.Address
}

// NewDataSource creates a new calldata source. It suppresses errors in fetching the L1 block if they occur.
// If there is an error, it will attempt to fetch the result on the next call to `Next`.
func NewDataSource(ctx context.Context, log log.Logger, cfg *rollup.Config, daCfg *rollup.DAConfig, fetcher L1TransactionFetcher, block eth.BlockID, batcherAddr common.Address) (DataIter, error) {
	_, txs, err := fetcher.InfoAndTxsByHash(ctx, block.Hash)
	if err != nil {
		return &DataSource{
			open:        false,
			id:          block,
			cfg:         cfg,
			fetcher:     fetcher,
			log:         log,
			batcherAddr: batcherAddr,
		}, nil
	} else {
		data, err := DataFromEVMTransactions(cfg, daCfg, batcherAddr, txs, log.New("origin", block))
		if err != nil {
			return &DataSource{
				open:        false,
				id:          block,
				cfg:         cfg,
				fetcher:     fetcher,
				log:         log,
				batcherAddr: batcherAddr,
			}, err
		}
		return &DataSource{
			open: true,
			data: data,
		}, nil
	}
}

// Next returns the next piece of data if it has it. If the constructor failed, this
// will attempt to reinitialize itself. If it cannot find the block it returns a ResetError
// otherwise it returns a temporary error if fetching the block returns an error.
func (ds *DataSource) Next(ctx context.Context) (eth.Data, error) {
	if !ds.open {
		if _, txs, err := ds.fetcher.InfoAndTxsByHash(ctx, ds.id.Hash); err == nil {
			ds.open = true
			ds.data, err = DataFromEVMTransactions(ds.cfg, ds.daCfg, ds.batcherAddr, txs, log.New("origin", ds.id))
			if err != nil {
				// already wrapped
				return nil, err
			}
		} else if errors.Is(err, ethereum.NotFound) {
			return nil, NewResetError(fmt.Errorf("failed to open calldata source: %w", err))
		} else {
			return nil, NewTemporaryError(fmt.Errorf("failed to open calldata source: %w", err))
		}
	}
	if len(ds.data) == 0 {
		return nil, io.EOF
	} else {
		data := ds.data[0]
		ds.data = ds.data[1:]
		return data, nil
	}
}

// TODO: test me
func bytesTo32CByteSlice(b *[]byte) [32]C.uint8_t {
	var x [32]C.uint8_t
	copy(x[:], (*[32]C.uint8_t)(unsafe.Pointer(&b))[:])
	return x
}

// DataFromEVMTransactions filters all of the transactions and returns the calldata from transactions
// that are sent to the batch inbox address from the batch sender address.
// This will return an empty array if no valid transactions are found.
func DataFromEVMTransactions(config *rollup.Config, daCfg *rollup.DAConfig, batcherAddr common.Address, txs types.Transactions, log log.Logger) ([]eth.Data, error) {
	var out []eth.Data
	l1Signer := config.L1Signer()
	for j, tx := range txs {
		if to := tx.To(); to != nil && *to == config.BatchInboxAddress {
			seqDataSubmitter, err := l1Signer.Sender(tx) // optimization: only derive sender if To is correct
			if err != nil {
				log.Warn("tx in inbox with invalid signature", "index", j, "err", err)
				continue // bad signature, ignore
			}
			// some random L1 user might have sent a transaction to our batch inbox, ignore them
			if seqDataSubmitter != batcherAddr {
				log.Warn("tx in inbox with unauthorized submitter", "index", j, "err", err)
				continue // not an authorized batch submitter, ignore
			}

			if daCfg != nil {
				frameRef := celestia.FrameRef{}
				frameRef.UnmarshalBinary(tx.Data())
				if err != nil {
					log.Warn("unable to decode frame reference", "index", j, "err", err)
					return nil, err
				}
				bytes, err := frameRef.MarshalBinary()
				if err != nil {
					log.Warn("unable to encode frame reference", "index", j, "err", err, "frameRef", frameRef)
					return nil, err
				}

				log.Info("requesting data from NEAR", "frameRef", frameRef, "bytes", bytes)

				blockHeight := C.uint64_t(frameRef.BlockHeight)
				defer C.free(unsafe.Pointer(&blockHeight))

				blob := C.get((*C.Client)(daCfg.Client), blockHeight)

				if blob == nil {
					errData := C.get_error()
					defer C.free(unsafe.Pointer(errData))
					if errData != nil {
						errStr := C.GoString(errData)
						log.Error("NEAR returned no blob", "err", errStr)
					}
					log.Warn("no data returned from near", "namespace", daCfg.Namespace, "height", frameRef.BlockHeight)
					continue
				} else {
					log.Info("got data from NEAR", "namespace", daCfg.Namespace, "height", frameRef.BlockHeight)
				}

				commitment := make([]byte, 32)
				copy(commitment, C.GoBytes(unsafe.Pointer(&blob.commitment), 32))

				if !reflect.DeepEqual(commitment, frameRef.TxCommitment) {
					log.Warn("Likely blob commitments dont match!")
				} else {
					log.Debug("Blob commitments match!")
				}
				bytes = C.GoBytes(unsafe.Pointer(blob.data), C.int(blob.len))

				out = append(out, bytes)
			} else {
				out = append(out, tx.Data())
			}
		}
	}
	return out, nil
}
