package main

import (
	"log"
	"os"
)

func main() {
	addr := os.Getenv("PLANNER_API_ADDR")
	if addr == "" {
		addr = ":3000"
	}

	if err := NewRouter(seedEvents()).Run(addr); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}
