package rollup

import (
	"context"
	"encoding/hex"

	openrpc "github.com/dndll/near-openrpc"
	openrpcns "github.com/dndll/near-openrpc/types/namespace"
	"github.com/dndll/near-openrpc/types/share"
)

type DAConfig struct {
	Namespace openrpcns.Namespace
	Client    *openrpc.Client
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
	config, err := openrpc.BuildConfig("testnet")
	if err != nil {
		return nil, err
	}
	config.KeyPath = keyPath

	client, err := openrpc.NewClient(context.Background(), *config, contract, account)
	if err != nil {
		return &DAConfig{}, err
	}

	return &DAConfig{
		Namespace: namespace.ToAppNamespace(),
		Client:    client,
	}, nil
}
