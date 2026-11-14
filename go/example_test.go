package uuid58_test

import (
	"errors"
	"fmt"

	uuid58 "github.com/nakanoasaservice/uuid58/go"
)

func ExampleEncode() {
	s, err := uuid58.Encode("f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf")
	fmt.Println(s, err)
	// Output: XDY9dmBbcMBXqcRvYw8xJ2 <nil>
}

func ExampleDecode() {
	u, err := uuid58.Decode("XDY9dmBbcMBXqcRvYw8xJ2")
	fmt.Println(u, err)

	_, err = uuid58.Decode("YcVfxkQb6JRzqk5kF2tNLw")
	fmt.Println(errors.Is(err, uuid58.ErrOverflow))
	// Output:
	// f4b247fd-1f87-45d4-aa06-1c6fc0a8dfaf <nil>
	// true
}

func ExampleIsValid() {
	fmt.Println(uuid58.IsValid("XDY9dmBbcMBXqcRvYw8xJ2"))
	fmt.Println(uuid58.IsValid("XDY9dmBbcMBXqcRvYw8xJ0"))
	// Output:
	// true
	// false
}

func ExampleEncodeBytes() {
	// Any [16]byte type in RFC 9562 order works, e.g. github.com/google/uuid.UUID.
	b := [16]byte{0xf4, 0xb2, 0x47, 0xfd, 0x1f, 0x87, 0x45, 0xd4, 0xaa, 0x06, 0x1c, 0x6f, 0xc0, 0xa8, 0xdf, 0xaf}
	fmt.Println(uuid58.EncodeBytes(b))
	// Output: XDY9dmBbcMBXqcRvYw8xJ2
}
