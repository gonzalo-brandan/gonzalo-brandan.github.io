function handler(event) {
  var request = event.request;
  var uri = request.uri;
  var host = request.headers.host ? request.headers.host.value : '';

  // Send www visitors to the bare domain, keeping the path.
  if (host.indexOf('www.') === 0) {
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: { location: { value: 'https://' + host.substring(4) + uri } }
    };
  }

  // Jekyll writes /posts/foo/index.html, but S3 doesn't resolve
  // "/posts/foo/" to its index file.
  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
  } else if (!uri.split('/').pop().includes('.')) {
    request.uri = uri + '/index.html';
  }

  return request;
}
