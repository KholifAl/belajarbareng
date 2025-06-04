String transformCloudinaryUrl(String url) {
  final parts = url.split('/upload/');
  if (parts.length != 2) return url;
  return '${parts[0]}/upload/w_200,c_limit,q_auto:eco/${parts[1]}';
}