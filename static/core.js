;$(function () {
    function syntaxHighlight(json) {
        if (typeof json != 'string') {
            json = JSON.stringify(json, undefined, 2);
        }
        json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, function (match) {
            var cls = 'number';
            if (/^"/.test(match)) {
                if (/:$/.test(match)) {
                    cls = 'key';
                } else {
                    cls = 'string';
                }
            } else if (/true|false/.test(match)) {
                cls = 'boolean';
            } else if (/null/.test(match)) {
                cls = 'null';
            }
            return '<span class="' + cls + '">' + match + '</span>';
        });
    }
  function findAnImage(searchString, startOffset) {
    var url = "/q?q=" + encodeURIComponent(searchString);

    $.get(url, function(data, textStatus, jqXHR) {
      var unescapedUrl, imageDiv
      // document.getElementById("response").innerHTML = syntaxHighlight(data)
      for (j = 0; j < data.length; j++) {
        var results = data[j].responseData.results;
        if (results && results.length > 0) {
          for (i = 0; i < results.length; i++) {
            unescapedUrl = results[i].unescapedUrl;
            imageDiv = document.getElementById("image-" +
                (j + 1).toString() + "-" +
                (i + 1).toString());
            if (imageDiv) {
              imageDiv.innerHTML = "<img src=\"" + unescapedUrl + "\" title=\"" + unescapedUrl + "\">";
            }
          }
        } else {
          for (i = 0; i < 4; i++) {
              imageDiv = document.getElementById("image-" +
                      (j + 1).toString() + "-" +
                      (i + 1).toString());
              if (imageDiv) {
                  imageDiv.innerHTML = "";
              }
          }
        }
      }
    }, "json");
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
