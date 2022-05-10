package endpoints

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHttpGet(t *testing.T) {
	req, err := http.NewRequest(http.MethodGet, REGIONLESS_RESOURCE_PATH, nil)
	if err != nil {
		t.Fatal(err)
	}
	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(ResourceHandler)
	handler.ServeHTTP(rr, req)
	fmt.Printf("rr.code: %v\n", rr.Code)
	fmt.Printf("rr.Body: %v\n", rr.Body)
	if status := rr.Code; status != http.StatusOK {
		t.Errorf("handler returned wrong status code: got %v want %v",
			status, http.StatusOK)
	}
}
