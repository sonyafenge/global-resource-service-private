package app

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"global-resource-service/resource-management/pkg/service-api/endpoints"

	"github.com/gorilla/mux"
)

/*
// NewAPIServerCommand creates a *cobra.Command object with default parameters
func NewAPIServerCommand() *cobra.Command {
	s := options.NewServerRunOptions()
	cmd := &cobra.Command{
		Use:  "service-api",
		Long: `regionless API service`,
		RunE: func(*cobra.Command, []string) error {

			return Run()
		},
	}
	return cmd
}

*/
// Run and create new service-api.  This should never exit.
func Run() error {
	fmt.Printf("Starting the API server...")
	// log to custom file
	LOG_FILE := "/tmp/service-api.log"
	// open log file
	logFile, err := os.OpenFile(LOG_FILE, os.O_APPEND|os.O_RDWR|os.O_CREATE, 0644)
	if err != nil {
		log.Panic(err)
	}
	defer logFile.Close()

	// Set log out put and enjoy :)
	log.SetOutput(logFile)

	// optional: log date-time, filename, and line number
	log.SetFlags(log.Lshortfile | log.LstdFlags)

	r := mux.NewRouter()
	r.HandleFunc(endpoints.REGIONLESS_RESOURCE_PATH, endpoints.ResourceHandler)
	server := &http.Server{
		Handler:      r,
		Addr:         "localhost:8080",
		WriteTimeout: 2 * time.Second,
		ReadTimeout:  2 * time.Second,
	}

	return server.ListenAndServe()
}
