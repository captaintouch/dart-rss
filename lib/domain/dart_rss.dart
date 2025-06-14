import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/domain/atom_feed.dart';
import 'package:dart_rss/domain/rss1_feed.dart';
import 'package:dart_rss/domain/rss_feed.dart';
import 'package:xml/xml.dart' as xml;
import 'package:intl/intl.dart';

extension SafeParseDateTime on DateTime {
  static DateTime safeParse(String str) {
    const dateFormatPatterns = [
      'EEE, d MMM yyyy HH:mm:ss Z',
    ];

    try {
      return DateTime.parse(str);
    } catch (_) {
      for (final pattern in dateFormatPatterns) {
        try {
          final format = DateFormat(pattern);
          return format.parse(str);
        } catch (_) {}
      }
    }
    return null;
  }
}

enum RssVersion {
  RSS1,
  RSS2,
  Atom,
  Unknown,
}

class WebFeed {
  WebFeed({
    @required this.title,
    @required this.description,
    @required this.links,
    @required this.items,
  });

  final String title;
  final String description;
  final List<String> links;
  final List<WebFeedItem> items;

  static WebFeed fromXmlString(String xmlString) {
    final rssVersion = detectRssVersion(xmlString);
    switch (rssVersion) {
      case RssVersion.RSS1:
        final rss1Feed = Rss1Feed.parse(xmlString);
        return WebFeed.fromRss1(rss1Feed);
        break;
      case RssVersion.RSS2:
        final rss2Feed = RssFeed.parse(xmlString);
        return WebFeed.fromRss2(rss2Feed);
        break;
      case RssVersion.Atom:
        final atomFeed = AtomFeed.parse(xmlString);
        return WebFeed.fromAtom(atomFeed);
        break;
      case RssVersion.Unknown:
        throw Error.safeToString(
            'Invalid XML String? We cannot detect RSS/Atom version.');
        break;
      default:
        throw Exception('Some error has occured.');
    }
  }

  static WebFeed fromRss1(Rss1Feed rss1feed) {
    return WebFeed(
      title: rss1feed.title ?? rss1feed.dc.title ?? '',
      description: rss1feed.description ?? rss1feed.dc?.description ?? '',
      links: [rss1feed.link],
      items: rss1feed.items
          .map(
            (item) => WebFeedItem(
              title: item.title ?? item.dc?.title ?? '',
              body: item.description ?? item.dc?.description ?? '',
              updated: SafeParseDateTime.safeParse(item.dc?.date),
              links: [item.link],
            ),
          )
          .toList(),
    );
  }

  static WebFeed fromRss2(RssFeed rssFeed) {
    return WebFeed(
      title: rssFeed.title ?? rssFeed.dc.title ?? '',
      description: rssFeed.description ?? rssFeed.dc.description ?? '',
      links: [rssFeed.link],
      items: rssFeed.items
          .map(
            (item) => WebFeedItem(
              title: item.title ?? item.dc.title ?? '',
              body: item.description ?? item.dc.description ?? '',
              updated: SafeParseDateTime.safeParse(item.pubDate) ??
                  SafeParseDateTime.safeParse(item.dc.date),
              links: [item.link],
            ),
          )
          .toList(),
    );
  }

  static WebFeed fromAtom(AtomFeed atomFeed) {
    return WebFeed(
      title: atomFeed.title,
      description: atomFeed.subtitle,
      links: atomFeed.links.map((atomLink) => atomLink.href).toList(),
      items: atomFeed.items
          .map(
            (item) => WebFeedItem(
              title: item.title,
              body: item.summary ?? item.content,
              updated: SafeParseDateTime.safeParse(item.updated) ??
                  SafeParseDateTime.safeParse(item.published),
              links: item.links.map((atomLink) => atomLink.href).toList(),
            ),
          )
          .toList(),
    );
  }

  static Future<WebFeed> fromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    return fromXmlString(response.body);
  }

  static RssVersion detectRssVersion(String xmlString) {
    final xmlDoc = xml.parse(xmlString);
    final rdfRefs = xmlDoc.findAllElements('rdf:RDF');
    final rssRefs = xmlDoc.findAllElements('rss');
    final feedRefs = xmlDoc.findAllElements('feed');

    if (rdfRefs.isNotEmpty) {
      return RssVersion.RSS1;
    } else if (rssRefs.isNotEmpty &&
        rssRefs.first.getAttribute('version').contains('2')) {
      return RssVersion.RSS2;
    } else if (feedRefs.isNotEmpty &&
        feedRefs.first.getAttribute('xmlns').toLowerCase().contains('atom')) {
      return RssVersion.Atom;
    }
    return RssVersion.Unknown;
  }
}

class WebFeedItem {
  WebFeedItem({
    this.title,
    this.body,
    this.links,
    this.updated,
  });

  final String title;
  final String body;
  final List<String> links;
  final DateTime updated;
}
