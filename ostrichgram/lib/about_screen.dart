import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    double containerWidth = MediaQuery.of(context).size.width * 0.6;
    containerWidth = containerWidth > 500 ? 500 : containerWidth;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF9D58FF),
        title: Text('About'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.popUntil(context, ModalRoute.withName('/'));
          },
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 16),

          Expanded(
            child: Center(
              child: FractionallySizedBox(
                heightFactor: 0.6,
                child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  width: containerWidth,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OstrichGram',
                        style: TextStyle(fontSize: 20),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'OstrichGram is free, open source software under the MIT license.  Learn more here: ',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      InkWell(
                        onTap: () => _launchURL('https://OstrichGram.com'),
                        child: Text(
                          'https://OstrichGram.com',
                          style: TextStyle(fontSize: 16, color: Colors.blue),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'You can also view or download the source code here:',
                        style: TextStyle(fontSize: 16),
                      ),
                      InkWell(
                        onTap: () => _launchURL('https://github.com/OstrichGram/OstrichGram'),
                        child: Text(
                          'https://github.com/OstrichGram/OstrichGram',
                          style: TextStyle(fontSize: 16, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                ),

              ),

            ),

          ),

          SizedBox(height: 32),

          Image.asset(
            'assets/images/og_logo.png',
            width: 60,
            height: 46,
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, ModalRoute.withName('/'));
            },
            child: Text('Return to Main Screen'),
          ),
          SizedBox(height: 16),

        ],
      ),
    );
  }
}
