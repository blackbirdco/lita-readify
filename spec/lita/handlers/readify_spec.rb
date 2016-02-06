require "spec_helper"

describe Lita::Handlers::Readify, lita_handler: true do
  let(:user) { Lita::User.create("1234", name: "Loïc", mention_name: "skelz0r") }
  let(:registry) do
    reg = Lita::Registry.new

    reg.register_handler(Lita::Handlers::Readify)

    reg.configure do |config|
      config.handlers.readify.consumer_key = "consumer_key"
      config.handlers.readify.consumer_secret = "consumer_secret"
      config.handlers.readify.access_token = "access_token"
      config.handlers.readify.access_token_secret = "access_token_secret"
      config.handlers.readify.blacklist_domains = ['google.com']
      config.handlers.readify.channels = ['#veilles', '#veilles-tech']
    end

    reg
  end

  # https://www.readability.com/reading-list/all?tags=must-read
  # https://www.readability.com/articles/3b7zsot2
  describe "link registration (without command)" do
    let(:channel) { "#veilles" }
    let(:message) { "Check this out : #{url} #{tags.map { |tag| "##{tag}" }.join(' ')}" }

    let(:url) { 'http://paulgraham.com/ds.html' }
    let(:tags) { ["must-read", "startup"] }

    let(:status) { '202' }
    let(:bookmark_id) { "bookmark_id" }
    let(:article_id) { "article_id" }

    before do
      allow_any_instance_of(Readit::API).to receive(:bookmark).and_return(
        OpenStruct.new(
          status: status,
          bookmark_id: bookmark_id,
          article_id: article_id
        )
      )

      allow_any_instance_of(Readit::API).to receive(:add_tags)
    end

    it { is_expected.to route(message).to(:register_link) }
    it { is_expected.to route(url).to(:register_link) }
    it { is_expected.to route("wow #{url}").to(:register_link) }
    it { is_expected.to route("#{url} wow").to(:register_link) }

    context "happy path" do
      it "saves link" do
        expect_any_instance_of(Readit::API).to receive(:bookmark).with(
          url: url
        )

        send_message(message, as: user, from: channel)
      end

      it "adds all tags to newly link: inline, username and channel name" do
        expect_any_instance_of(Readit::API).to receive(:add_tags).with(
          bookmark_id,
          ['skelz0r', 'veilles'].concat(tags).join(',')
        )

        send_message(message, as: user, from: channel)
      end

      it "replies with article link formatted and tags" do
        send_message(message, as: user, from: channel)

        expect(replies.last).to eq(
          "*Link*: https://www.readability.com/articles/#{article_id}\n" +
            "*Tags*: #{['skelz0r', 'veilles'].concat(tags).map { |tag| "##{tag}" }.join(' ')}"
        )
      end
    end

    describe "when links already added (409)" do
      let(:status) { '409' }

      it "responds nothing" do
        send_message(message, as: user, from: channel)

        replies.count.should == 0
      end
    end

    describe "with blacklist url" do
      let(:url) { "https://www.google.com" }

      it "responds nothing" do
        send_message(message, as: user, from: channel)

        replies.count.should == 0
      end

      it "doesn't save link" do
        expect_any_instance_of(Readit::API).not_to receive(:bookmark)

        send_message(message, as: user, from: channel)
      end
    end

    describe "on not registered channel" do
      let(:channel) { "#general" }

      it "responds nothing" do
        send_message(message, as: user, from: channel)

        replies.count.should == 0
      end

      it "doesn't save link" do
        expect_any_instance_of(Readit::API).not_to receive(:bookmark)

        send_message(message, as: user, from: channel)
      end
    end
  end

  describe "add tag to link" do
    # it { is_expected.to route().to(:add_tag_to_link) }
  end
end
