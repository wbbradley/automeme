package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMemoryStorage(t *testing.T) {
	ms := newMemoryStorage()

	imageRanks := ms.GetImageRanks()
	assert.Equal(t, len(imageRanks), 0, "New MemoryStorage is empty.")

	ms.Meme("me", "http://foo.bar/z.gif")

	imageRanks = ms.GetImageRanks()
	assert.Equal(t, len(imageRanks), 1, "Meme adds an image to the list.")

	ms.Unmeme("me", "http://foo.bar/z.gif")

	imageRanks = ms.GetImageRanks()
	assert.Equal(t, len(imageRanks), 1, "Unmeme removes an image from the list.")

	/* don't crash */
	ms.Unmeme("me-bad", "http://foo.bar/z.gif")
	ms.Unmeme("me-bad", "http://foo.bar/z2.gif")
}

func TestMemeFactor(t *testing.T) {
	assert.True(t, calculateMemeFactor(2, 1134028003) > calculateMemeFactor(1, 1134028003), "math")
	assert.True(t, calculateMemeFactor(3, 1134028003) > calculateMemeFactor(1, 1134028003), "math")
	assert.True(t, calculateMemeFactor(300, 1134028003) < calculateMemeFactor(1, 1144028003), "math")
}
