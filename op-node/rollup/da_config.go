package rollup

/*
#cgo LDFLAGS: -L../../lib -lnear_da_op_rpc_sys -lssl -lcrypto -lm
#include "../../lib/libnear-da-op-rpc.h"
#include <stdlib.h>
*/
import "C"

import (
	"unsafe"
)

type Namespace struct {
	Version uint8
	Id      uint32
}

type DAConfig struct {
	Namespace Namespace
	Client    *C.Client
}

// TODO: test me
func bytesTo32CByteSlice(b *[]byte) [32]C.uint8_t {
	var x [32]C.uint8_t
	copy(x[:], (*[32]C.uint8_t)(unsafe.Pointer(&b))[:])
	return x
}

func NewDAConfig(account, contract, key string, ns uint32) (*DAConfig, error) {
	// TODO: reuse this
	daClient := C.new_client(C.CString(account), C.CString(key), C.CString(contract), C.CString("testnet"), C.uint8_t(0), C.uint(ns))
	return &DAConfig{
		Namespace: Namespace{ Version: 0, Id: ns },
		Client:    daClient,
	}, nil
}
