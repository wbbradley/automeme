$(function () {
    function getParameterByName(name) {
        name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
        var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
        results = regex.exec(location.search);
        return results === null ? "" : decodeURIComponent(results[1].replace(/\+/g, " "));
    }
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

            
            var imageResults = _(data)
                .map(function(d) {
                    var results = d.responseData.results;
                    return _.isEmpty(results) ? [] : results;
                })
                .flatten()
                .value();

            // NOTE: Uses implicit DOM order
            var imageContainers = $('.image-container'); 
            _(imageContainers)
                .zip(imageResults)
                .each(function(ztuple) {
                    displayResultInImageContainer(ztuple[0], ztuple[1]);
                })
                .value();
        }, "json");
    }

    function displayResultInImageContainer(container, result) {
        if (!container) {
          return;
        }

        // Replace contents with result if it exists, otherwise clear
        $(container).find('.image').empty();
        if (result) {
          var imageElt = $("<img>")
            .attr('src', result.unescapedUrl)
            .attr('title', result.unescapedUrl);
          $(container).find('.image').empty().append(imageElt);
        }
    }

    function performSearch() {
        event.preventDefault();
        var searchText = $('#js-search-text').val();
        if (searchText) {
            window.location.hash = searchText.replace(/ /g, "+");
            findAnImage(searchText, 0);
        }
        return false;
    }

    function performElementAction(e) {
        var action = $(e.currentTarget).data('action');
        var actionFunc = actionMap[action];
        if (!actionFunc) {
          console.log("Unrecognized action:", action);
          return;
        }
        return actionFunc(e);
    }

    function memeImage(elt) {
        memeAction(elt, "/⬆");
    }

    function unmemeImage(elt) {
        memeAction(elt, "/⬇");
    }

    function memeAction(elt, endpoint) {
      var xhr = $.ajax({
        type: 'POST',
        url: endpoint,
        data: JSON.stringify({
          url: $(elt.target).parents('.image-container').find('.image img').attr('src'),
        }),
      });
      xhr.done(function() {
        console.log("(Un)memed successfully");
      });
    }

    var actionMap = {
      'meme': memeImage,
      'unmeme': unmemeImage,
    };

    document.getElementById('js-image-form').addEventListener('submit', performSearch, false);
    document.getElementById('js-search-button').addEventListener('click', performSearch, false);

    var query = getParameterByName('q');

    if (!query) {
        query = window.location.hash;
    }

    if (query && query[0] == '#') {
        query = query.substr(1);
    }

    query = query.replace(/\+/g, ' ');
    query = decodeURIComponent(query);

    if (query && query.length > 0) {
        $('#js-search-text').val(query);
        performSearch();
    }

    $(document).on('click', '[data-action]', performElementAction);
    window.setInterval(function() {
        var xhr = $.ajax({
            type: 'GET',
            url: "/memes",
        });
        xhr.done(function(data) {
            imageRanks = _.sortBy(data.imageRanks, function (item) { return -item.score });
            // TODO: put these images into a display container, probably time to use react
            console.log(imageRanks);
        });
    }, 15000);
});
