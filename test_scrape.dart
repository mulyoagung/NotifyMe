import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  final url = 'https://dokumentasi-rektorat.vercel.app/';
  final selector =
      'body.inter_fe8b9d92-module__LINzvG__variable > main.flex-1 > div.container > div.grid:nth-child(4)';

  final response = await http.get(Uri.parse(url));
  print('Status Code: ${response.statusCode}');

  final document = parse(response.body);
  print(response.body);

  try {
    final elements = document.querySelectorAll(selector);
    print('Found ${elements.length} elements for given selector.');
    if (elements.isNotEmpty) {
      print('Extracted Text:');
      print(elements.map((e) => e.text).join('\n').trim());
    }
  } catch (e) {
    print('Error querying selector: $e');
  }
}
