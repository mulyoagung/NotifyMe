import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../models/monitored_link.dart';

class ScraperService {
  static Future<String?> fetchAndExtract(MonitoredLink link) async {
    try {
      final response = await http
          .get(Uri.parse(link.url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final document = parse(response.body);
        String extractedText = '';

        if (link.cssSelector.isNotEmpty) {
          final elements = document.querySelectorAll(link.cssSelector);
          if (elements.isNotEmpty) {
            extractedText = elements.map((e) => e.text).join('\n').trim();
          } else {
            // Fallback if selector is not found
            extractedText = '';
          }
        } else {
          extractedText = document.body?.text.trim() ?? '';
        }

        // Clean up excessive whitespaces
        extractedText = extractedText.replaceAll(RegExp(r'\s+'), ' ');
        return extractedText;
      }
    } catch (e) {
      print('Error fetching link \${link.url}: $e');
    }
    return null;
  }
}
