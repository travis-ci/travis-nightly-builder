describe Travis::NightlyBuilder::App do
  include Rack::Test::Methods
  let(:owner) { 'carrots' }
  let(:language_archives) { [OpenStruct.new(lang: 'erlang', os: 'linux', release: 'xenial', arch: 'x86_64')] }
  let(:runner) { Travis::NightlyBuilder::Runner.new(api_endpoint: 'http://api.local:90', owner: owner) }

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

  before :each do
    allow_any_instance_of(described_class).to receive(:files)
      .with(['erlang','os','release','arch']).and_return(language_archives)
    allow_any_instance_of(described_class).to receive(:runner)
      .and_return(runner)
    allow(runner).to receive(:build_conn).and_return(conn)
  end

  def app
    Travis::NightlyBuilder::App
  end

  it 'says hello' do
    get '/hello'
    expect(last_response).to be_ok
    expect(last_response.body.strip).to eq('ohai')
  end

  describe "/builds endpoints" do
    it 'returns HTML data when requested' do
      get '/builds/erlang/os/release/arch'

      expect(last_response).to be_ok
      expect(last_response.header["Content-Type"]).to start_with('text/html')
    end

    it 'returns valid JSON data when requested' do
      header 'Accept', 'application/json'
      get '/builds/erlang/os/release/arch'

      expect(last_response).to be_ok
      expect(last_response.header["Content-Type"]).to eq('application/json')
      expect { JSON.parse(last_response.body) }.not_to raise_error
    end

    it 'returns valid YAML data when requested' do
      header 'Accept', 'text/yaml'
      get '/builds/erlang/os/release/arch'

      expect(last_response).to be_ok
      expect(last_response.header["Content-Type"]).to eq('text/yaml;charset=utf-8')
      expect { YAML.load(last_response.body) }.not_to raise_error
    end
  end

  describe 'POST /build' do
    # stub requests from `runner`
    let :stubs do
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post('/repo/carrots%2Ftravis-erlang-builder/requests') do
          [ 201, {}, Travis::NightlyBuilder::Test::POST_REQUEST_RESPONSE_BODY ]
        end
        stub.get('/repo/39521/request/205729') do
          [ 200, {}, Travis::NightlyBuilder::Test::GET_REQUEST_RESPONSE_BODY ]
        end
      end
    end

    let(:repo) { 'travis-erlang-builder' }

    context 'when posting with well-formed data' do
      it 'redirects to build page' do
        header 'Content-Type', 'application/json'
        post "/build?repo=#{repo}"

        expect(last_response.status).to eq(302)
        expect(last_response.header["Location"]).to eq("https://travis-ci.com/#{owner}/#{repo}/builds/127202117")
      end
    end
  end
end
