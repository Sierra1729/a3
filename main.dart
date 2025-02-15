import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print("🔥 Firebase Initialized Successfully!");
  } catch (e) {
    print("❌ Firebase Initialization Error: $e");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ICMR Proposals Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ProposalFetcher(),
    );
  }
}

class ProposalFetcher extends StatefulWidget {
  @override
  _ProposalFetcherState createState() => _ProposalFetcherState();
}

class _ProposalFetcherState extends State<ProposalFetcher> {
  List<Map<String, String>> proposals = [];
  bool isLoading = false;
  String message = "✅ App Loaded Successfully!";

  /// Fetches data from the ICMR website and sends it to the backend
  Future<void> fetchICMRProposals() async {
    setState(() {
      isLoading = true;
      message = "Fetching from Website...";
    });

    try {
      final url = Uri.parse('http://localhost:8080/proposals');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final rows = document.querySelectorAll('tbody tr');

        proposals.clear();

        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          final linkElement = row.querySelector('a.descView__link');

          String title = cells.length > 1 ? cells[1].text.trim() : 'No Title';
          String link =
              linkElement != null ? linkElement.attributes['href'] ?? '' : '';

          proposals.add({'Title': title, 'Link': link});

          // 🔹 Send Data to Backend
          await http.post(
            Uri.parse('http://localhost:8080/send-notification'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"title": title, "link": link}),
          );
        }

        setState(() {
          isLoading = false;
          message = "✅ Data fetched from Website!";
        });
      } else {
        setState(() {
          message =
              "❌ Failed to fetch data. Status code: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        message = "❌ Error: $e";
        isLoading = false;
      });
    }
  }

  /// Fetches stored notifications from Firebase via the backend
  Future<void> fetchFromFirebase() async {
    setState(() {
      isLoading = true;
      message = "Fetching from Firebase...";
    });

    try {
      final response =
          await http.get(Uri.parse('http://localhost:8080/get-notifications'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        List<Map<String, String>> fetchedNotifications =
            (data['data'] as List<dynamic>).map<Map<String, String>>((doc) {
          return {
            'Title': doc['title']?.toString() ?? '',
            'Link': doc['link']?.toString() ?? '',
          };
        }).toList();

        setState(() {
          proposals = fetchedNotifications;
          isLoading = false;
          message = "✅ Data fetched from Firebase!";
        });
      } else {
        setState(() {
          message = "❌ Error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        message = "❌ Error fetching from Firebase: $error";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ICMR Proposals Dashboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              message,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: fetchICMRProposals,
                child: Text('Fetch from Website'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: fetchFromFirebase,
                child: Text('Fetch from Firebase'),
              ),
            ],
          ),
          SizedBox(height: 20),
          isLoading
              ? CircularProgressIndicator()
              : proposals.isEmpty
                  ? Text('No proposals found.')
                  : Expanded(
                      child: ListView.builder(
                        itemCount: proposals.length,
                        itemBuilder: (context, index) {
                          final proposal = proposals[index];
                          return Card(
                            margin: EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(proposal['Title'] ?? ''),
                              trailing: Icon(Icons.arrow_forward),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailsPage(
                                      title: proposal['Title'] ?? '',
                                      link: proposal['Link'] ?? '',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  final String title;
  final String link;

  DetailsPage({required this.title, required this.link});

  Future<void> _launchURL(BuildContext context) async {
    final fullLink =
        link.startsWith('http') ? link : 'https://www.icmr.gov.in/$link';

    if (await canLaunch(fullLink)) {
      await launch(fullLink);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _launchURL(context),
          child: Text('Open Document'),
        ),
      ),
    );
  }
}
