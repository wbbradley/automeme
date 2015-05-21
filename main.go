package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strconv"
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

// Handle existence queries
func queryServerGet(w http.ResponseWriter, req *http.Request) {
	query := req.FormValue("q")
	fmt.Println("querying for", query)
	w.Header().Set("Content-Type", "application/json")

	var url = "https://ajax.googleapis.com" +
		"/ajax/services/search/images" +
		"?v=1.0&as_filetype=gif&q=" + url.QueryEscape(query) +
		"&start=0"
	resp, err := http.Get(url)
	if err != nil {
		log.Println("it's a 406")
		w.WriteHeader(406)
		return
	}
	defer resp.Body.Close()

	buf := make([]byte, 1024*4)
	for {
		n, _ := resp.Body.Read(buf)
		if n > 0 {
			w.Write(buf[:n])
		} else {
			break
		}
	}
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
