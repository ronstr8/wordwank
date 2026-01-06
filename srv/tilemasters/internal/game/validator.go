package game

import (
	"fmt"
	"net/http"
)

type Validator interface {
	ValidateWord(word string) bool
}

type RemoteValidator struct {
	WorddURL string
}

func (v *RemoteValidator) ValidateWord(word string) bool {
	url := fmt.Sprintf("%s/validate/%s", v.WorddURL, word)
	resp, err := http.Get(url)
	if err != nil {
		fmt.Printf("Error validating word: %v\n", err)
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}
