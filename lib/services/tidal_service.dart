import '../models/search_models.dart';

class TidalService {
  Future<SearchResult> search(SearchParams params) async {
    final encoded = Uri.encodeComponent(params.query);
    final url = 'https://listen.tidal.com/search?q=$encoded';

    return SearchResult(
      results: [SearchResultItem(url: url, title: params.query)],
    );
  }
}
