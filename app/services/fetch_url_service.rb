require "faraday"

class FetchUrlService
  MAX_CHARS  = 2000
  USER_AGENT = "Mozilla/5.0 (compatible; CollectiveCRM-Agent/1.0)"

  def self.fetch(url)
    new.fetch(url)
  end

  def fetch(url)
    response = Faraday.get(url, nil, "User-Agent" => USER_AGENT)
    extract_content(response.body, url)
  rescue => e
    "Could not fetch #{url}: #{e.message}"
  end

  private

  def extract_content(html, _url)
    title = html.match(/<title[^>]*>(.*?)<\/title>/mi)&.captures&.first&.strip || ""
    meta  = html.match(/<meta\s+name="description"\s+content="([^"]+)"/i)&.captures&.first&.strip || ""
    paras = html.scan(/<p[^>]*>(.*?)<\/p>/mi)
                .flatten
                .map { |p| p.gsub(/<[^>]+>/, "").strip }
                .reject(&:blank?)
                .first(5)
                .join(" ")

    [
      title.presence && "Title: #{title}",
      meta.presence  && "Description: #{meta}",
      paras.presence
    ].compact.join("\n").truncate(MAX_CHARS)
  end
end
