;$(function () {
  function findAnImage(searchString, startOffset) {
    var url = "/q?q=" + encodeURIComponent(searchString);

    $.get(url, function(data, textStatus, jqXHR) {
      var unescapedUrl, imageDiv

      console.dir(data);
      var results = data.responseData.results;
      if (results && results.length > 0) {
       for (i = 0; i < results.length; i++) {
          unescapedUrl = results[i].unescapedUrl;
          imageDiv = document.getElementById("image-" + (i + 1).toString());
          if (imageDiv) {
            imageDiv.style.backgroundImage = "url(" + unescapedUrl + ")";
          }
       }
      }
    }, "json");
    /*
       if result?.content?
       results = (JSON.parse result.content)?.responseData?.results
       if results and results.length > 0
       */
  }

  function performSearch() {
    event.preventDefault();
    var searchText = $('#js-search-text').val();
    if (searchText) {
      findAnImage(searchText, 0);
    }
    return false;
  }

  document.getElementById('js-image-form').addEventListener('submit', performSearch, false);
  document.getElementById('js-search-button').addEventListener('click', performSearch, false);
});
