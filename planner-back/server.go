package main

import (
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

type Event struct {
	ID          string    `json:"id"`
	Summary     string    `json:"summary"`
	Description string    `json:"description"`
	Start       time.Time `json:"start"`
	End         time.Time `json:"end"`
	Location    string    `json:"location"`
	Color       string    `json:"color"`
}

type ProblemDetails struct {
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status int    `json:"status"`
	Detail string `json:"detail"`
}

func NewRouter(events []Event) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())
	router.Use(cors.New(buildCORSConfig()))

	v1 := router.Group("/v1")
	v1.OPTIONS("/events", func(c *gin.Context) {
		c.Status(http.StatusNoContent)
	})

	protected := v1.Group("")
	protected.Use(requireUserID())
	protected.GET("/events", listEvents(events))

	return router
}

func buildCORSConfig() cors.Config {
	rawOrigins := os.Getenv("PLANNER_CORS_ORIGINS")
	if rawOrigins == "" {
		rawOrigins = "http://localhost:5173"
	}

	parts := strings.Split(rawOrigins, ",")
	origins := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			origins = append(origins, trimmed)
		}
	}
	if len(origins) == 0 {
		origins = []string{"http://localhost:5173"}
	}

	return cors.Config{
		AllowOrigins:              origins,
		AllowMethods:              []string{http.MethodGet, http.MethodOptions},
		AllowHeaders:              []string{"Origin", "Content-Type", "Accept", "user-id"},
		OptionsResponseStatusCode: http.StatusNoContent,
		MaxAge:                    12 * time.Hour,
	}
}

func requireUserID() gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method == http.MethodOptions {
			c.Next()
			return
		}

		if c.GetHeader("user-id") == "" {
			writeProblem(
				c,
				http.StatusUnauthorized,
				"Unauthorized",
				"API token is missing or invalid",
			)
			c.Abort()
			return
		}
		c.Next()
	}
}

func listEvents(events []Event) gin.HandlerFunc {
	return func(c *gin.Context) {
		if os.Getenv("PLANNER_FORCE_EVENTS_ERROR") == "1" {
			writeProblem(
				c,
				http.StatusInternalServerError,
				"Internal Server Error",
				"An error occurred while processing the request",
			)
			return
		}

		startFilter, err := parseOptionalTime(c.Query("start"))
		if err != nil {
			writeProblem(c, http.StatusBadRequest, "Bad Request", "invalid start query value, use RFC3339")
			return
		}

		endFilter, err := parseOptionalTime(c.Query("end"))
		if err != nil {
			writeProblem(c, http.StatusBadRequest, "Bad Request", "invalid end query value, use RFC3339")
			return
		}

		if startFilter != nil && endFilter != nil && endFilter.Before(*startFilter) {
			writeProblem(c, http.StatusBadRequest, "Bad Request", "end query value cannot be before start")
			return
		}

		filtered := filterEvents(events, startFilter, endFilter)
		c.JSON(http.StatusOK, filtered)
	}
}

func parseOptionalTime(value string) (*time.Time, error) {
	if value == "" {
		return nil, nil
	}

	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return nil, err
	}
	return &parsed, nil
}

func filterEvents(events []Event, startFilter, endFilter *time.Time) []Event {
	if startFilter == nil && endFilter == nil {
		return events
	}

	filtered := make([]Event, 0, len(events))
	for _, event := range events {
		if startFilter != nil && event.End.Before(*startFilter) {
			continue
		}
		if endFilter != nil && event.Start.After(*endFilter) {
			continue
		}
		filtered = append(filtered, event)
	}

	return filtered
}

func writeProblem(c *gin.Context, status int, title, detail string) {
	c.JSON(status, ProblemDetails{
		Type:   "about:blank",
		Title:  title,
		Status: status,
		Detail: detail,
	})
}

func seedEvents() []Event {
	base := time.Date(2026, time.February, 16, 9, 0, 0, 0, time.UTC)
	return []Event{
		{
			ID:          "evt-1",
			Summary:     "Sprint Planning",
			Description: "Plan stories for the next sprint",
			Start:       base,
			End:         base.Add(90 * time.Minute),
			Location:    "Room A / Zoom",
			Color:       "#0859dbff",
		},
		{
			ID:          "evt-2",
			Summary:     "1:1",
			Description: "Weekly sync",
			Start:       base.Add(26 * time.Hour),
			End:         base.Add(27 * time.Hour),
			Location:    "Room B",
			Color:       "#eebb22ff",
		},
		{
			ID:          "evt-3",
			Summary:     "Hackathon with a very long title that should be truncated on the UI",
			Description: "Cross-team product hackathon",
			Start:       base.Add(25 * time.Hour),
			End:         base.Add(72*time.Hour + 52*time.Hour),
			Location:    "Innovation Lab",
			Color:       "#54ca00ff",
		},
		{
			ID:          "evt-4",
			Summary:     "Another longevent",
			Description: "Cross-team product hackathon",
			Start:       base.Add(42 * time.Hour),
			End:         base.Add(92*time.Hour + 52*time.Hour),
			Location:    "Innovation Lab",
			Color:       "#f3d00aff",
		},

		{
			ID:          "evt-5",
			Summary:     "yet another event with a long title that should be truncated on the UI with multiple lines",
			Description: "Cross-team product hackathon",
			Start:       time.Date(2026, time.February, 25, 8, 0, 0, 0, time.UTC),
			End:         time.Date(2026, time.March, 3, 10, 0, 0, 0, time.UTC),
			Location:    "Innovation Lab",
			Color:       "#f3540aff",
		},

		{
			ID:          "evt-6",
			Summary:     "should be truncated on the UI with multiple lines",
			Description: "Cross-team product hackathon",
			Start:       time.Date(2026, time.February, 19, 8, 0, 0, 0, time.UTC),
			End:         time.Date(2026, time.February, 21, 10, 0, 0, 0, time.UTC),
			Location:    "Innovation Lab",
			Color:       "#05d2e1ff",
		},
	}
}
