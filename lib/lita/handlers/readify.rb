require 'readit'

module Lita
  module Handlers
    class Readify < Handler
      config :consumer_key
      config :consumer_secret
      config :access_token
      config :access_token_secret

      config :blacklist_domains
      config :channels

      # http://rubular.com/r/qWCVVYZ31S
      URL_WITH_OR_WITHOUT_HTTP = /(https?):\/\/.*|^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,6}(:[0-9]{1,5})?(\/.*)?/

      route(
        URL_WITH_OR_WITHOUT_HTTP,
        :register_link,
        command: false
      )

      def register_link(r)
        return unless authorized_channel?(r.room.name)

        tags = [r.user.mention_name, r.room.name.gsub('#', '')]
        links = []
        words = r.message.body.scan(/\S+|\n+/)

        words.each do |word|
          if word =~ URL_WITH_OR_WITHOUT_HTTP && !blacklist?(word)
            link = save_link(word)
            links << link.dup unless link.status == '409'
          end
        end

        if links.any?
          words.each do |word|
            if word =~ /#(\S+)/
              tags << $1
            end
          end

          links.each do |link|
            add_tags_to_link(link, tags)
            r.reply(saved_link_message(link, tags))
          end
        end
      end

      private

      def authorized_channel?(channel)
        config.channels.include?(channel)
      end

      def blacklist?(url)
        config.blacklist_domains.any? { |domain| url.match(domain) }
      end

      def save_link(url)
        api.bookmark(url: url)
      end

      def add_tags_to_link(link, tags)
        api.add_tags(
          link.bookmark_id,
          tags.join(',')
        )
      end

      def api
        @api ||= begin
          Readit::Config.consumer_key = config.consumer_key
          Readit::Config.consumer_secret = config.consumer_secret

          Readit::API.new(
            config.access_token,
            config.access_token_secret
          )
        end
      end

      def saved_link_message(link, tags)
        "*Link*: https://www.readability.com/articles/#{link.article_id}\n" +
          "*Tags*: #{tags.map { |tag| "##{tag}" }.join(' ')}"
      end
    end

    Lita.register_handler(Readify)
  end
end
