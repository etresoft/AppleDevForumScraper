<?xml version="1.0"?>

<xsl:stylesheet
  version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>

  <!-- Output indented HTML 5.0 code in UTF-8. -->
  <xsl:output method="xml" encoding="utf-8" indent="yes"/>

  <!-- Convert a page node into an HTML document. -->
  <xsl:template match="/people">

    <page>
      <head>
        <title>Etresoft.org: Developer Forum Documentation</title>
      </head>
      <body>
        <name>Developer Forum Documentation</name>
        <content>
          <h1>Comments by Apple employees on the Apple Developer forums</h1>
          <ul>
            <xsl:apply-templates select="person"/>
          </ul>
        </content>
      </body>
    </page>

  </xsl:template>
  
  <xsl:template match="person">
    
    <li>
      <xsl:value-of select="name"/>
      
      <xsl:if test="string-length(title) > 0">
        <xsl:text> - </xsl:text>
        <xsl:value-of select="title"/>
      </xsl:if>

      <xsl:if test="count(post[string-length(title) > 0]) > 0">
        <ul>
          <xsl:apply-templates select="post"/>
        </ul>
      </xsl:if>
    </li>

  </xsl:template>
  
  <xsl:template match="post">

    <xsl:if test="string-length(title) > 0">
      <li>
        <a target="_blank">
          <xsl:attribute name="href">
            <xsl:value-of select="url"/>
          </xsl:attribute>

          <xsl:value-of select="title"/>
        </a>
      </li>
    </xsl:if>

  </xsl:template>

</xsl:stylesheet>
