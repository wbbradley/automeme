package main

import (
	"fmt"
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
	memoryImage, ok := ms.imagesByUrl[imageUrl]
	if ok {
		memoryImage.userMemes[userId] = 1
	} else {
		now := time.Now()
		memoryImage = &MemoryImage{
			imageUrl,
			now.Unix(),
			0,
			map[UserId]int{},
		}
		ms.imagesByUrl[imageUrl] = memoryImage
	}
	memoryImage.computeScore()
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
	mi.score = 123
}
