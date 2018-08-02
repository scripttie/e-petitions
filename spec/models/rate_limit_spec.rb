require 'rails_helper'

RSpec.describe RateLimit, type: :model do
  subject { described_class.create! }

  describe "validations" do
    it { is_expected.to validate_presence_of(:burst_rate) }
    it { is_expected.to validate_numericality_of(:burst_rate).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:burst_period) }
    it { is_expected.to validate_numericality_of(:burst_period).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:sustained_rate) }
    it { is_expected.to validate_numericality_of(:sustained_rate).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:sustained_period) }
    it { is_expected.to validate_numericality_of(:sustained_period).only_integer.is_greater_than(0) }
    it { is_expected.to validate_length_of(:allowed_domains).is_at_most(10000) }
    it { is_expected.to validate_length_of(:allowed_ips).is_at_most(10000) }
    it { is_expected.to validate_length_of(:blocked_domains).is_at_most(50000) }
    it { is_expected.to validate_length_of(:blocked_ips).is_at_most(50000) }
    it { is_expected.to validate_length_of(:countries).is_at_most(2000) }

    context "when the sustained rate is less than the burst rate" do
      before do
        subject.update(sustained_rate: 10, burst_rate: 20)
      end

      it "adds an error message" do
        expect(subject.valid?).to eq(false)
        expect(subject.errors[:sustained_rate]).to include("Sustained rate must be greater than burst rate")
      end
    end

    context "when the sustained period is less than the burst period" do
      before do
        subject.update(sustained_period: 30, burst_period: 60)
      end

      it "adds an error message" do
        expect(subject.valid?).to eq(false)
        expect(subject.errors[:sustained_period]).to include("Sustained period must be greater than burst period")
      end
    end

    context "when the allowed domain list is invalid" do
      before do
        subject.update(allowed_domains: "(foo")
      end

      it "adds an error message" do
        expect(subject.valid?).to eq(false)
        expect(subject.errors[:allowed_domains]).to include("Allowed domains list is invalid")
      end
    end

    context "when the allowed IPs list is invalid" do
      before do
        subject.update(allowed_ips: "foo")
      end

      it "adds an error message" do
        expect(subject.valid?).to eq(false)
        expect(subject.errors[:allowed_ips]).to include("Allowed IPs list is invalid")
      end
    end

    context "when the blocked domain list is invalid" do
      before do
        subject.update(blocked_domains: "(foo")
      end

      it "adds an error message" do
        expect(subject.valid?).to eq(false)
        expect(subject.errors[:blocked_domains]).to include("Blocked domains list is invalid")
      end
    end

    context "when the blocked IPs list is invalid" do
      before do
        subject.update(blocked_ips: "foo")
      end

      it "adds an error message" do
        expect(subject.valid?).to eq(false)
        expect(subject.errors[:blocked_ips]).to include("Blocked IPs list is invalid")
      end
    end
  end

  describe "#exceeded?" do
    let(:petition) { FactoryBot.create(:open_petition) }
    let(:signature) { FactoryBot.create(:pending_signature, petition: petition) }

    let(:allowed_domains) { "" }
    let(:allowed_ips) { "" }

    let(:blocked_domains) { "" }
    let(:blocked_ips) { "" }

    let(:countries) { "" }
    let(:geoblocking_enabled) { false }

    subject do
      described_class.create!(
        burst_rate: 10, burst_period: 60,
        sustained_rate: 20, sustained_period: 300,
        allowed_domains: allowed_domains, allowed_ips: allowed_ips,
        blocked_domains: blocked_domains, blocked_ips: blocked_ips,
        countries: countries, geoblocking_enabled: geoblocking_enabled
      )
    end

    shared_examples_for "allowed domains" do
      let(:allowed_domains) { "foo.com\n*.bar.com\n**.baz.com\n" }

      it "returns true when the domain is not allowed" do
        allow(signature).to receive(:domain).and_return("example.com")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns false when the domain is allowed" do
        allow(signature).to receive(:domain).and_return("foo.com")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns false when the domain is allowed by a grep pattern" do
        allow(signature).to receive(:domain).and_return("foo.bar.com")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns false when the domain is allowed by a recursive grep pattern" do
        allow(signature).to receive(:domain).and_return("foo.bar.baz.com")
        expect(subject.exceeded?(signature)).to eq(false)
      end
    end

    shared_examples_for "blocked domains" do
      let(:blocked_domains) { "foo.com\n*.bar.com\n**.baz.com\n" }

      it "returns false when the domain is not blocked" do
        allow(signature).to receive(:domain).and_return("example.com")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns true when the domain is blocked" do
        allow(signature).to receive(:domain).and_return("foo.com")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns true when the domain is blocked by a grep pattern" do
        allow(signature).to receive(:domain).and_return("foo.bar.com")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns true when the domain is blocked by a recursive grep pattern" do
        allow(signature).to receive(:domain).and_return("foo.bar.baz.com")
        expect(subject.exceeded?(signature)).to eq(true)
      end
    end

    shared_examples_for "allowed IPs" do
      let(:allowed_ips) { "10.0.1.1\n10.0.1.2/32\n10.0.2.0/28\n" }

      it "returns true when the IP address is not allowed" do
        allow(signature).to receive(:ip_address).and_return("10.1.1.1")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns false when the IP address is allowed" do
        allow(signature).to receive(:ip_address).and_return("10.0.1.1")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns false when the IP address is allowed by a CIDR address" do
        allow(signature).to receive(:ip_address).and_return("10.0.1.2")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns false when the IP address is allowed by a CIDR range" do
        allow(signature).to receive(:ip_address).and_return("10.0.2.7")
        expect(subject.exceeded?(signature)).to eq(false)
      end
    end

    shared_examples_for "blocked IPs" do
      let(:blocked_ips) { "10.0.1.1\n10.0.1.2/32\n10.0.2.0/28\n" }

      it "returns false when the IP address is not blocked" do
        allow(signature).to receive(:ip_address).and_return("10.1.1.1")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns true when the IP address is blocked" do
        allow(signature).to receive(:ip_address).and_return("10.0.1.1")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns true when the IP address is blocked by a CIDR address" do
        allow(signature).to receive(:ip_address).and_return("10.0.1.2")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns true when the IP address is blocked by a CIDR range" do
        allow(signature).to receive(:ip_address).and_return("10.0.2.7")
        expect(subject.exceeded?(signature)).to eq(true)
      end
    end

    shared_examples_for "GeoIP blocking" do
      let(:geoblocking_enabled) { true }
      let(:countries) { "United Kingdom" }
      let(:geoip_db_path) { "/path/to/GeoLite2-Country.mmdb" }
      let(:geoip_db) { double(:geoip_db) }
      let(:geoip_result) { double(:geoip_result) }
      let(:country) { double(:country) }

      before do
        allow(MaxMindDB).to receive(:new).with(geoip_db_path).and_return(geoip_db)
        allow(geoip_db).to receive(:lookup).with("12.34.56.78").and_return(geoip_result)
        allow(signature).to receive(:ip_address).and_return("12.34.56.78")
        allow(geoip_result).to receive(:found?).and_return(true)
        allow(geoip_result).to receive(:country).and_return(country)
      end

      it "returns false when the country is allowed" do
        allow(country).to receive(:name).and_return("United Kingdom")
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it "returns true when the country is not allowed" do
        allow(country).to receive(:name).and_return("Neverland")
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it "returns true when a result is not found" do
        allow(geoip_result).to receive(:found?).and_return(false)
        expect(subject.exceeded?(signature)).to eq(true)
      end
    end

    context "when both rates are below the threshold" do
      before do
        allow(signature).to receive(:rate).with(60).and_return(5)
        allow(signature).to receive(:rate).with(300).and_return(10)
      end

      it "returns false" do
        expect(subject.exceeded?(signature)).to eq(false)
      end

      it_behaves_like "blocked domains"
      it_behaves_like "blocked IPs"
      it_behaves_like "GeoIP blocking"
    end

    context "when the burst rate is above the threshold" do
      before do
        allow(signature).to receive(:rate).with(60).and_return(15)
        allow(signature).to receive(:rate).with(300).and_return(10)
      end

      it "returns true" do
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it_behaves_like "allowed domains"
      it_behaves_like "allowed IPs"
    end

    context "when the sustained rate is above the threshold" do
      before do
        allow(signature).to receive(:rate).with(60).and_return(5)
        allow(signature).to receive(:rate).with(300).and_return(30)
      end

      it "returns true" do
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it_behaves_like "allowed domains"
      it_behaves_like "allowed IPs"
    end

    context "when both rates are above the threshold" do
      before do
        allow(signature).to receive(:rate).with(60).and_return(15)
        allow(signature).to receive(:rate).with(300).and_return(30)
      end

      it "returns true" do
        expect(subject.exceeded?(signature)).to eq(true)
      end

      it_behaves_like "allowed domains"
      it_behaves_like "allowed IPs"
    end
  end

  describe "#allowed_domains=" do
    subject do
      described_class.new(allowed_domains: " foo.com\r\nbar.com\r\n")
    end

    it "normalizes line endings and strips whitespace" do
      expect(subject.allowed_domains).to eq("foo.com\nbar.com")
    end
  end

  describe "#allowed_ips=" do
    subject do
      described_class.new(allowed_ips: " 192.168.1.1\r\n10.0.1.1/32\r\n")
    end

    it "normalizes line endings and strips whitespace" do
      expect(subject.allowed_ips).to eq("192.168.1.1\n10.0.1.1/32")
    end
  end

  describe "#blocked_domains=" do
    subject do
      described_class.new(blocked_domains: " foo.com\r\nbar.com\r\n")
    end

    it "normalizes line endings and strips whitespace" do
      expect(subject.blocked_domains).to eq("foo.com\nbar.com")
    end
  end

  describe "#blocked_ips=" do
    subject do
      described_class.new(blocked_ips: " 192.168.1.1\r\n10.0.1.1/32\r\n")
    end

    it "normalizes line endings and strips whitespace" do
      expect(subject.blocked_ips).to eq("192.168.1.1\n10.0.1.1/32")
    end
  end

  describe "#countries=" do
    subject do
      described_class.new(countries: " United Kingdom\r\nIreland\r\n")
    end

    it "normalizes line endings and strips whitespace" do
      expect(subject.countries).to eq("United Kingdom\nIreland")
    end
  end

  describe "#allowed_domains_list" do
    subject do
      described_class.create!(allowed_domains: allowed_domains)
    end

    context "when there is extra whitespace" do
      let :allowed_domains do
        <<-EOF
          foo.com
             bar.com

        EOF
      end

      it "is is stripped" do
        expect(subject.allowed_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end

    context "when there are blank lines" do
      let :allowed_domains do
        <<-EOF
          foo.com

             bar.com

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end

    context "when there are line comments" do
      let :allowed_domains do
        <<-EOF
          # This is a test
          foo.com

             bar.com

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end

    context "when there are inline comments" do
      let :allowed_domains do
        <<-EOF
          foo.com # This is a test

             bar.com

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end
  end

  describe "#allowed_ips_list" do
    subject do
      described_class.create!(allowed_ips: allowed_ips)
    end

    let(:ip_addr_1) { IPAddr.new("10.0.1.1") }
    let(:ip_addr_2) { IPAddr.new("192.168.1.0/24") }

    context "when there is extra whitespace" do
      let :allowed_ips do
        <<-EOF
          10.0.1.1
             192.168.1.0/24

        EOF
      end

      it "is is stripped" do
        expect(subject.allowed_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end

    context "when there are blank lines" do
      let :allowed_ips do
        <<-EOF
          10.0.1.1

             192.168.1.0/24

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end

    context "when there are line comments" do
      let :allowed_ips do
        <<-EOF
          # This is a test
          10.0.1.1

             192.168.1.0/24

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end

    context "when there are inline comments" do
      let :allowed_ips do
        <<-EOF
          10.0.1.1 # This is a test

             192.168.1.0/24

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end
  end

  describe "#blocked_domains_list" do
    subject do
      described_class.create!(blocked_domains: blocked_domains)
    end

    context "when there is extra whitespace" do
      let :blocked_domains do
        <<-EOF
          foo.com
             bar.com

        EOF
      end

      it "is is stripped" do
        expect(subject.blocked_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end

    context "when there are blank lines" do
      let :blocked_domains do
        <<-EOF
          foo.com

             bar.com

        EOF
      end

      it "they are stripped" do
        expect(subject.blocked_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end

    context "when there are line comments" do
      let :blocked_domains do
        <<-EOF
          # This is a test
          foo.com

             bar.com

        EOF
      end

      it "they are stripped" do
        expect(subject.blocked_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end

    context "when there are inline comments" do
      let :blocked_domains do
        <<-EOF
          foo.com # This is a test

             bar.com

        EOF
      end

      it "they are stripped" do
        expect(subject.blocked_domains_list).to eq([/\Afoo.com\z/, /\Abar.com\z/])
      end
    end
  end

  describe "#blocked_ips_list" do
    subject do
      described_class.create!(blocked_ips: blocked_ips)
    end

    let(:ip_addr_1) { IPAddr.new("10.0.1.1") }
    let(:ip_addr_2) { IPAddr.new("192.168.1.0/24") }

    context "when there is extra whitespace" do
      let :blocked_ips do
        <<-EOF
          10.0.1.1
             192.168.1.0/24

        EOF
      end

      it "is is stripped" do
        expect(subject.blocked_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end

    context "when there are blank lines" do
      let :blocked_ips do
        <<-EOF
          10.0.1.1

             192.168.1.0/24

        EOF
      end

      it "they are stripped" do
        expect(subject.blocked_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end

    context "when there are line comments" do
      let :blocked_ips do
        <<-EOF
          # This is a test
          10.0.1.1

             192.168.1.0/24

        EOF
      end

      it "they are stripped" do
        expect(subject.blocked_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end

    context "when there are inline comments" do
      let :blocked_ips do
        <<-EOF
          10.0.1.1 # This is a test

             192.168.1.0/24

        EOF
      end

      it "they are stripped" do
        expect(subject.blocked_ips_list).to eq([ip_addr_1, ip_addr_2])
      end
    end
  end

  describe "#allowed_countries" do
    subject do
      described_class.create!(countries: countries)
    end

    let(:country_1) { "United Kingdom" }
    let(:country_2) { "Ireland" }

    context "when there is extra whitespace" do
      let :countries do
        <<-EOF
          United Kingdom
             Ireland

        EOF
      end

      it "is is stripped" do
        expect(subject.allowed_countries).to eq([country_1, country_2])
      end
    end

    context "when there are blank lines" do
      let :countries do
        <<-EOF
          United Kingdom

             Ireland

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_countries).to eq([country_1, country_2])
      end
    end

    context "when there are line comments" do
      let :countries do
        <<-EOF
          # This is a test
          United Kingdom

             Ireland

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_countries).to eq([country_1, country_2])
      end
    end

    context "when there are inline comments" do
      let :countries do
        <<-EOF
          United Kingdom # This is a test

             Ireland

        EOF
      end

      it "they are stripped" do
        expect(subject.allowed_countries).to eq([country_1, country_2])
      end
    end
  end
end
