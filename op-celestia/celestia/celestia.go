package celestia

import (
	"encoding"
	"errors"
)

var (
	ErrInvalidSize = errors.New("invalid size")
)

// Framer defines a way to encode/decode a FrameRef.
type Framer interface {
	encoding.BinaryMarshaler
	encoding.BinaryUnmarshaler
}

// FrameRef contains the reference to the specific frame on celestia and
// satisfies the Framer interface.
type FrameRef struct {
	TxId  []byte
	TxCommitment []byte
}

var _ Framer = &FrameRef{}

// MarshalBinary encodes the FrameRef to binary
// serialization format: height + commitment
//
//	----------------------------------------
//
// | 32 byte txid  |  32 byte commitment   |
//
//	----------------------------------------
//
// | <-- txid --> | <-- commitment -->    |
//
//	----------------------------------------
func (f *FrameRef) MarshalBinary() ([]byte, error) {
	ref := make([]byte, len(f.TxId)+len(f.TxCommitment))

	copy(ref[:32], f.TxId)
	copy(ref[32:], f.TxCommitment)

	return ref, nil
}

// UnmarshalBinary decodes the binary to FrameRef
// serialization format: height + commitment
//
//	----------------------------------------
//
// | 32 byte txid  |  32 byte commitment   |
//
//	----------------------------------------
//
// | <-- txid --> | <-- commitment -->    |
//
//	----------------------------------------
func (f *FrameRef) UnmarshalBinary(ref []byte) error {
	if len(ref) <= 63 {
		return ErrInvalidSize
	}
	f.TxId = ref[:32]
	f.TxCommitment = ref[32:]
	return nil
}
