describe Travis::NightlyBuilder::App do
  include Rack::Test::Methods

  def app
    Travis::NightlyBuilder::App
  end

  it 'says hello' do
    get '/hello'
    expect(last_response).to be_ok
    expect(last_response.body.strip).to eq('ohai')
  end
end
