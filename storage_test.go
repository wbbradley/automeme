package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMemoryStorage(t *testing.T) {
	ms := newMemoryStorage()

	imageRanks := ms.GetImageRanks("me")
	assert.Equal(t, len(imageRanks), 0, "New MemoryStorage is empty.")

	ms.Meme("me", "http://foo.bar/z.gif")

	imageRanks = ms.GetImageRanks("me")
	assert.Equal(t, len(imageRanks), 1, "Meme adds an image to the list.")

	ms.Unmeme("me", "http://foo.bar/z.gif")

	imageRanks = ms.GetImageRanks("me")
	assert.Equal(t, len(imageRanks), 1, "Unmeme removes an image from the list.")
}
