# frozen_string_literal: true

require "spec_helper"
require "scrapyard/yard"
require "scrapyard/key"

RSpec.describe Scrapyard::Yard do
  let(:s3) { Aws::S3::Client.new(stub_responses: true) }
  let(:log) { spy }
  let(:yard) { Scrapyard::AwsS3Yard.new("", log, client: s3) }
  let(:now) { Time.now }

  context "search" do
    it "returns nil if bucket is empty" do
      s3.stub_responses(:list_objects, contents: [])
      expect(yard.search(["foo"])).to be_nil
    end

    it "finds key if match" do
      s3.stub_responses(
        :list_objects, contents: [{key: 'key.tgz', last_modified: now}]
      )

      expect(yard.search(["key"])).to eq("key.tgz")
      expect(yard.search(%w[foo key])).to eq("key.tgz")
    end

    it "finds most recent key when bucket contains multiple matches" do
      s3.stub_responses(
        :list_objects, contents: [
          {key: 'key-old.tgz', last_modified: now - 100},
          {key: 'key-new.tgz', last_modified: now}
        ]
      )

      expect(yard.search(["key"])).to eq("key-new.tgz")
      expect(yard.search(["key-old", "key"])).to eq("key-old.tgz")
    end

    it "finds first matching prefix when matching multiple" do
      s3.stub_responses(
        :list_objects, contents: [
          {key: 'key-1.tgz', last_modified: now},
          {key: 'key-2.tgz', last_modified: now}
        ]
      )

      expect(yard.search(["key"])).to eq("key-1.tgz")
      expect(yard.search(%w[foo bar])).to be_nil
      expect(yard.search(["key-2", "key"])).to eq("key-2.tgz")
    end
  end

  context "fetch" do
    before do
      FileUtils.rmtree 'scrapy'
      FileUtils.mkdir_p 'scrapy'
    end
    after { FileUtils.rmtree 'scrapy' }

    let(:local) { 'scrapy/key.tgz' }
    it "downloads from s3" do
      key = instance_double(Scrapyard::Key, local: local, to_s: 'key.tgz')
      s3.stub_responses(
        :get_object, lambda do |ctx|
          if ctx.params[:key] == "key.tgz"
            { body: 'contents' }
          else
            'NotFound'
          end
        end
      )
      expect { yard.fetch(key) }.to change { File.exist?(local) }.to(true)
      expect(IO.read(local)).to eq 'contents'
      expect(log).to have_received(:info).with(/Downloaded/)
    end
  end
end
