package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

var (
	host = flag.String("host", "", "Specify the server host to listen on")
	port = flag.Int("port", 8001, "Specify the server port to listen on")
)

func queryServer(w http.ResponseWriter, req *http.Request) {
	if req.Method == "GET" {
		queryServerGet(w, req)
	} else {
		w.WriteHeader(400)
	}
}

type Response struct {
	statusCode int
	data       string
}

func getRemoteIP(req *http.Request) string {
	forwarded_for := req.Header.Get("x-forwarded-for")
	ips := strings.Split(forwarded_for, ", ")
	var userip string
	if len(ips) > 0 && len(ips[0]) > 0 {
		userip = ips[0]
	} else {
		userip = req.RemoteAddr
	}
	log.Println("getRemoteIP found", userip)
	return userip
}

// Handle existence queries
func queryServerGet(w http.ResponseWriter, req *http.Request) {
	query := req.FormValue("q")
	fmt.Println("querying for", query)
	w.Header().Set("Content-Type", "application/json")
	responses := make(chan Response)
	userip := getRemoteIP(req)

	for j := 0; j < 2; j++ {
		go func(j int) {
			var response Response
			var url = "https://ajax.googleapis.com" +
				"/ajax/services/search/images" +
				"?v=1.0&as_filetype=gif&q=" + url.QueryEscape(query) +
				"&as_sitesearch=gifbin.com" +
				"&safe=off" +
				"&userip=" + url.QueryEscape(userip) +
				"&start=" + fmt.Sprint(j*4)
			resp, err := http.Get(url)
			if err != nil {
				response.statusCode = resp.StatusCode
				responses <- response
				return
			}
			defer resp.Body.Close()
			response.statusCode = 200
			response.data = ""

			buf := make([]byte, 1024*4)
			for {
				n, _ := resp.Body.Read(buf)
				if n > 0 {
					response.data += string(buf[:n])
				} else {
					break
				}
			}
			responses <- response
		}(j)
	}

	w.WriteHeader(200)
	w.Write([]byte("["))
	sep := ""
	for i := 0; i < 2; i++ {
		response := <-responses
		if response.statusCode/100 == 2 {
			w.Write([]byte(sep))
			w.Write([]byte(response.data))
			sep = ","
		}
	}
	w.Write([]byte("]"))

	close(responses)
}

func main() {
	flag.Parse()

	http.HandleFunc("/q", queryServer)
	http.Handle("/", http.FileServer(http.Dir("static")))
	err := http.ListenAndServe(*host+":"+strconv.Itoa(*port), nil)
	if err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
