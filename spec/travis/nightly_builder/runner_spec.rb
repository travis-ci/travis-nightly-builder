describe Travis::NightlyBuilder::Runner do
  subject do
    described_class.new(api_endpoint: 'http://api.local:90', owner: 'carrots')
  end

  let :stubs do
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/') { |*| [200, {}, 'huh.'] }
    end
  end

  let :conn do
    Faraday.new do |faraday|
      faraday.adapter :test, stubs
    end
  end

  before do
    allow(subject).to receive(:build_conn).and_return(conn)
  end

  it 'has an api endpoint' do
    expect(subject).to respond_to(:api_endpoint)
  end

  it 'has a token' do
    expect(subject).to respond_to(:token)
  end

  context 'with successful request' do
    let :stubs do
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post('/repo/carrots%2Fkale/requests') do
          [
            201,
            {},
            { ok: :sure }.to_json
          ]
        end
      end
    end

    it 'returns the raw response' do
      expect(subject.run(repo: 'kale')).to respond_to(:body)
    end
  end
end
