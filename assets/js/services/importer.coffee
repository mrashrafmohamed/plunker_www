#= require ../services/plunks

plunkerRegex = ///
  ^
    \s*                   # Leading whitespace
    (?:plunk:)?           # Optional plunk:prefix
    ([-\._a-zA-Z0-9]+)     # Plunk ID
    \s*                   # Trailing whitespace
  $
///i

githubRegex = ///
  ^
    \s*                   # Leading whitespace
    (?:                   # Optional protocol/hostname
      (?:https?\://)?     # Protocol
      gist\.github\.com/  # Hostname
    |
      gist\:
    )
    ([0-9]+|[0-9a-z]{20}) # Gist ID
    (?:#.+)?              # Optional anchor
    \s*                   # Trailing whitespace
  $
///i


module = angular.module("plunker.importer", ["plunker.plunks"])

module.factory "importer", [ "$q", "$http", "plunks", ($q, $http, plunks) ->
  import: (source) ->
    deferred = $q.defer()
    
    if matches = source.match(plunkerRegex)
      plunks.findOrCreate(id: matches[1]).refresh().then (plunk) ->
        deferred.resolve
          description: plunk.description
          tags: angular.copy(plunk.tags)
          files: angular.copy(plunk.files)
          plunk: angular.copy(plunk)
      , (error) ->
        deferred.reject("Plunk not found")
    else if matches = source.match(githubRegex)
      request = $http.jsonp("https://api.github.com/gists/#{matches[1]}?callback=JSON_CALLBACK")
      
      request.then (response) ->
        if response.data.meta.status >= 400 then deferred.reject("Gist not found")
        else
          gist = response.data.data
          json = {}
          
          if manifest = gist.files["plunker.json"]
            try
              angular.extend json, angular.fromJson(manifest.content)
            catch e
              console.error "Unable to parse manifest file:", e

  
          angular.extend json,
            source:
              type: "gist"
              url: gist.html_url
              title: "gist:#{gist.id}"
            files: {}
          
          json.description = json.source.description = gist.description if gist.description

          for filename, file of gist.files
            unless filename == "plunker.json"
              json.files[filename] =
                filename: filename
                content: file.content 
          
          deferred.resolve(json)
    else deferred.reject("Not a recognized source")
          
    deferred.promise
]