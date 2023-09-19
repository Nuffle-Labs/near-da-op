package rollup

/*
#cgo LDFLAGS: -L../../lib -lnear_da_op_rpc_sys -lssl -lcrypto -lm
#include "../../lib/libnear-da-op-rpc.h"
#include <stdlib.h>
*/
import "C"

import (
	"errors"
	"fmt"
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

func NewDAConfig(accountN, contractN, keyN string, ns uint32) (*DAConfig, error) {
	account := C.CString(accountN)
	defer C.free(unsafe.Pointer(account))

	key := C.CString(keyN)
	defer C.free(unsafe.Pointer(key))

	contract := C.CString(contractN)
	defer C.free(unsafe.Pointer(contract))

	network := C.CString("testnet")
	defer C.free(unsafe.Pointer(network))

	namespaceId := C.uint(ns)
	defer C.free(unsafe.Pointer(&namespaceId))

	namespaceVersion := C.uint8_t(0)
	defer C.free(unsafe.Pointer(&namespaceVersion))

	daClient := C.new_client(account, key, contract, network, namespaceVersion, namespaceId)
	if daClient == nil {
		errData := C.get_error()
		defer C.free(unsafe.Pointer(errData))

		if errData != nil {
			errStr := C.GoString(errData)
			return nil, fmt.Errorf("unable to create NEAR DA client %s", errStr)
		}
		return nil, errors.New("unable to create NEAR DA client")
	}

	return &DAConfig{
		Namespace: Namespace{Version: 0, Id: ns},
		Client:    daClient,
	}, nil
}
