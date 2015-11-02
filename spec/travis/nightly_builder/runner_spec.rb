describe Travis::NightlyBuilder::Runner do
  it 'has an api endpoint' do
    expect(subject).to respond_to(:api_endpoint)
  end

  it 'has a token' do
    expect(subject).to respond_to(:token)
  end
end
