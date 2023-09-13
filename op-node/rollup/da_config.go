package rollup

/*
#cgo LDFLAGS: -L../../lib -lnear_da_op_rpc_sys
#include "../../lib/libnear-da-op-rpc.h"
#include <stdlib.h>
*/
import "C"

import (
	"encoding/hex"
	"unsafe"

	openrpcns "github.com/dndll/near-openrpc/types/namespace"
	"github.com/dndll/near-openrpc/types/share"
)

type DAConfig struct {
	Namespace openrpcns.Namespace
	Client    *C.Client
}

// TODO: test me
func bytesTo32CByteSlice(b *[]byte) [32]C.uint8_t {
	var x [32]C.uint8_t
	copy(x[:], (*[32]C.uint8_t)(unsafe.Pointer(&b))[:])
	return x
}

func NewDAConfig(account, contract, keyPath, ns string) (*DAConfig, error) {
	nsBytes, err := hex.DecodeString(ns)
	if err != nil {
		return &DAConfig{}, err
	}

	namespace, err := share.NewBlobNamespaceV0(nsBytes)
	if err != nil {
		return nil, err
	}

	// TODO: reuse this
	// TODO: convert these
	daClient := C.new_client(C.CString(keyPath), C.CString(contract), C.CString("testnet"), (*C.uint8_t)(C.CBytes(nsBytes)))

	if err != nil {
		return &DAConfig{}, err
	}

	return &DAConfig{
		Namespace: namespace.ToAppNamespace(),
		Client:    daClient,
	}, nil
}
