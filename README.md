# AppleDevForumScraper
Scrape Apple Developer forums for accidental documentation by Apple engineers

scrapePeople.pl - Perl script to pull postings from anyone identified as an Apple employee. Saves data to an XML file. This uses the Jive Activity service that pulls only recent postings. This script must be run on a regular basis to archive all posts.

people.xsl - An XSLT script to convert the XML output of scrapePeople.pl into HTML.
