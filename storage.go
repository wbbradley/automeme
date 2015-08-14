package main

import (
	"fmt"
	"math"
	"time"
)

type UserId string
type ImageURL string

type ImageRank struct {
	imageUrl ImageURL
	score    float64
}

type Storage interface {
	GetImageRanks(userId UserId) []ImageRank
	Meme(userId UserId, imageUrl ImageURL)
	Unmeme(userId UserId, imageUrl ImageURL)
}

type MemoryImage struct {
	url       ImageURL
	timestamp int64
	score     float64
	userMemes map[UserId]int
}

type MemoryStorage struct {
	imagesByUrl map[ImageURL]*MemoryImage
}

func newMemoryStorage() Storage {
	return &MemoryStorage{
		map[ImageURL]*MemoryImage{},
	}
}

func (ms MemoryStorage) GetImageRanks(userId UserId) []ImageRank {
	imageRanks := make([]ImageRank, 0)
	for url, memoryImage := range ms.imagesByUrl {
		imageRanks = append(imageRanks, ImageRank{
			url,
			memoryImage.score,
		})
	}
	return imageRanks
}

func (ms *MemoryStorage) Meme(userId UserId, imageUrl ImageURL) {
	fmt.Println("meming", imageUrl)
	memoryImage, ok := ms.imagesByUrl[imageUrl]
	if !ok {
		fmt.Println("didn't find", imageUrl, ", so we're adding it")
		now := time.Now()
		memoryImage = &MemoryImage{
			imageUrl,
			now.Unix(),
			0,
			map[UserId]int{},
		}
		ms.imagesByUrl[imageUrl] = memoryImage
	}

	fmt.Println("found", imageUrl, ", so we're upvoting it")

	memoryImage.userMemes[userId] = 1
	memoryImage.computeScore()
	fmt.Println(imageUrl, "now has a score of", memoryImage.score)
}

func (ms *MemoryStorage) Unmeme(userId UserId, imageUrl ImageURL) {
	memoryImage, ok := ms.imagesByUrl[imageUrl]
	if ok {
		fmt.Println("deleting ", imageUrl)
		delete(memoryImage.userMemes, userId)
		memoryImage.computeScore()
	}
}

func (mi *MemoryImage) computeScore() {
	netMemes := 0
	for _, userScore := range mi.userMemes {
		netMemes += userScore
	}
	mi.score = calculateMemeFactor(netMemes, float64(mi.timestamp))
}

func calculateMemeFactor(netMemes int, timestamp float64) float64 {
	order := math.Log10(math.Max(math.Abs(float64(netMemes)), 1))
	var sign int
	if netMemes > 0 {
		sign = 1
	} else if netMemes < 0 {
		sign = -1
	} else {
		sign = 0
	}
	seconds := timestamp - 1134028003
	return float64(sign)*order + seconds/45000.0
}
