package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

var (
	host        = flag.String("host", "", "Specify the server host to listen on")
	port        = flag.Int("port", 8001, "Specify the server port to listen on")
	memeStorage = newMemoryStorage()
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
	log.Println("querying for", query)
	w.Header().Set("Content-Type", "application/json")
	responses := make(chan Response)
	userip := getRemoteIP(req)

	for j := 0; j < 2; j++ {
		go func(j int) {
			var response Response
			// Default to failure, unless we're able to replace this response
			// with a success
			response.statusCode = 500
			defer func() { responses <- response }()

			var url = "https://ajax.googleapis.com" +
				"/ajax/services/search/images" +
				"?v=1.0&as_filetype=gif&q=" + url.QueryEscape(query) +
				// "&as_sitesearch=gifbin.com" +
				"&safe=off" +
				"&userip=" + url.QueryEscape(userip) +
				"&start=" + fmt.Sprint(j*4)
			resp, err := http.Get(url)
			if err != nil {
				response.statusCode = resp.StatusCode
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

type memePacket struct {
	Url ImageURL
}

type MemeAction func(UserId, ImageURL)

func meme(w http.ResponseWriter, req *http.Request) {
	handleMemeAction(w, req, memeStorage.Meme)
}

func unmeme(w http.ResponseWriter, req *http.Request) {
	handleMemeAction(w, req, memeStorage.Unmeme)
}

func handleMemeAction(w http.ResponseWriter, req *http.Request, memeAction MemeAction) {
	body, err := ioutil.ReadAll(req.Body)
	if err != nil {
		panic("bad")
	}
	log.Println(string(body))
	var t memePacket
	err = json.Unmarshal(body, &t)
	if err == nil {
		w.WriteHeader(200)
		memeAction("me", t.Url)
	} else {
		w.WriteHeader(400)
		log.Println(err)
	}
}

type imageRankPacket struct {
	Url   ImageURL `json:"url"`
	Score float64  `json:"score"`
}

type imageRanksPacket struct {
	ImageRanks []imageRankPacket `json:"imageRanks"`
}

func memes(w http.ResponseWriter, req *http.Request) {
	imageRanks := memeStorage.GetImageRanks()
	packet := new(imageRanksPacket)
	packet.ImageRanks = make([]imageRankPacket, 0)

	w.Header().Set("Content-Type", "application/json")

	for _, imageRank := range imageRanks {
		packet.ImageRanks = append(
			packet.ImageRanks,
			imageRankPacket{
				imageRank.ImageUrl,
				imageRank.Score,
			})
	}

	encoder := json.NewEncoder(w)
	encoder.Encode(&packet)
}

func main() {
	flag.Parse()

	http.HandleFunc("/q", queryServer)
	http.HandleFunc("/meme", meme)
	http.HandleFunc("/⬆", meme)
	http.HandleFunc("/unmeme", unmeme)
	http.HandleFunc("/⬇", unmeme)
	http.HandleFunc("/memes", memes)
	http.HandleFunc("/☛", memes)
	http.Handle("/", http.FileServer(http.Dir("static")))
	err := http.ListenAndServe(*host+":"+strconv.Itoa(*port), nil)
	if err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
