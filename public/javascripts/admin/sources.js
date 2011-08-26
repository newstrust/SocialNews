/*
 The returned format from teh autocomplete will be 
 name|email|id
*/

function formatItem(row) {
    return row[0] + " <i>" + row[1] + "</i>";
}

$(document).ready(function() {
    $("#autocomplete").autocomplete(SEARCH_PATH, {
        minChars: 2,
        matchSubset: 1,
        matchContains: 1,
        cacheLength: 10,
        dataType: 'json',
        formatItem: formatItem
    });

    $('input#autocomplete').result(function(event, data, formatted) {
        //SSS: Commented this line -- this fails in Linux FF3
        //console.log(typeof(data));
        if (data && typeof(data) == 'object') {
            var slug;
            (data[2] === '' ) ? slug = data[3] : slug = data[2];
            window.location = REDIRECT_PATH +'/'+ slug;
        }
    });
});
