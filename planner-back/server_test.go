package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestGetEventsRequiresUserID(t *testing.T) {
	router := NewRouter(seedEvents())

	req := httptest.NewRequest(http.MethodGet, "/v1/events", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status %d, got %d", http.StatusUnauthorized, rec.Code)
	}
}

func TestGetEventsSuccess(t *testing.T) {
	router := NewRouter(seedEvents())

	req := httptest.NewRequest(http.MethodGet, "/v1/events", nil)
	req.Header.Set("user-id", "user-123")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	var events []Event
	if err := json.Unmarshal(rec.Body.Bytes(), &events); err != nil {
		t.Fatalf("expected JSON events response: %v", err)
	}
	if len(events) == 0 {
		t.Fatalf("expected at least one event")
	}
}

func TestGetEventsBadStartQuery(t *testing.T) {
	router := NewRouter(seedEvents())

	req := httptest.NewRequest(http.MethodGet, "/v1/events?start=invalid", nil)
	req.Header.Set("user-id", "user-123")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestGetEventsFiltersByRange(t *testing.T) {
	events := seedEvents()
	router := NewRouter(events)

	start := events[1].Start.Add(-time.Minute).Format(time.RFC3339)
	end := events[1].End.Add(time.Minute).Format(time.RFC3339)
	req := httptest.NewRequest(http.MethodGet, "/v1/events?start="+start+"&end="+end, nil)
	req.Header.Set("user-id", "user-123")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	var filtered []Event
	if err := json.Unmarshal(rec.Body.Bytes(), &filtered); err != nil {
		t.Fatalf("expected JSON events response: %v", err)
	}
	if len(filtered) != 1 {
		t.Fatalf("expected exactly one filtered event, got %d", len(filtered))
	}
	if filtered[0].ID != events[1].ID {
		t.Fatalf("expected event %s, got %s", events[1].ID, filtered[0].ID)
	}
}

func TestPreflightIncludesCORSHeaders(t *testing.T) {
	router := NewRouter(seedEvents())

	req := httptest.NewRequest(http.MethodOptions, "/v1/events", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	req.Header.Set("Access-Control-Request-Method", http.MethodGet)
	req.Header.Set("Access-Control-Request-Headers", "user-id")

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("expected status %d, got %d", http.StatusNoContent, rec.Code)
	}

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "http://localhost:5173" {
		t.Fatalf("expected access-control-allow-origin header, got %q", got)
	}
}
