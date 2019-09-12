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
            {
              "@type": "pending",
              "remaining_requests": 1,
              "repository": {
                "@type": "repository",
                "@href": "/repo/39521",
                "@representation": "minimal",
                "id": 39521,
                "name": "test-2",
                "slug": "svenfuchs/test-2"
              },
              "request": {
                "repository": {
                  "id": 44258138,
                  "owner_name": "svenfuchs",
                  "name": "test-2"
                },
                "user": {
                  "id": 3664
                },
                "id": 205729,
                "message": nil,
                "branch": "master",
                "config": {
                }
              },
              "resource_type": "request"
            }.to_json
          ]
        end
        stub.get('/repo/39521/request/205729') do
          [
            200,
            {},
            {
              "@type":                  "request",
              "@href":                  "/repo/39521/request/205729",
              "@representation":        "standard",
              "id":                     205729,
              "state":                  "finished",
              "result":                 "approved",
              "message":                nil,
              "pull_request_mergeable": nil,
              "repository":             {
                "@type":                "repository",
                "@href":                "/repo/39521",
                "@representation":      "minimal",
                "id":                   39521,
                "name":                 "test-2",
                "slug":                 "svenfuchs/test-2"
              },
              "branch_name":            "default",
              "commit":                 {
                "@type":                "commit",
                "@representation":      "minimal",
                "id":                   242021782,
                "sha":                  "c6b5fc20a9edc76d0201bd549e6e640a8e8cc1a8",
                "ref":                  nil,
                "message":              "build branch=default; source=; env=\&quot;VERSION=3.7.4\&quot; 20190912T140059Z",
                "compare_url":          "https://github.com/svenfuchs/test-2/compare/cfce26283605ba0f686b98ec664a1e10efccb5e2...c6b5fc20a9edc76d0201bd549e6e640a8e8cc1a8",
                "committed_at":         "2019-09-11T20:21:26Z"
              },
              "builds":                 [
                {
                  "@type":               "build",
                  "@href":               "/build/127202117",
                  "@representation":     "minimal",
                  "id":                  127202117,
                  "number":              "7008",
                  "state":               "canceled",
                  "duration":            0,
                  "event_type":          "api",
                  "previous_state":      "canceled",
                  "pull_request_title":  nil,
                  "pull_request_number": nil,
                  "started_at":          nil,
                  "finished_at":         "2019-09-12T14:01:11Z",
                  "private":             false
                }
              ],
              "owner":                  {
                "@type":                "organization",
                "@href":                "/org/31",
                "@representation":      "minimal",
                "id":                   31,
                "login":                "svenfuchs"
              },
              "created_at":             "2019-09-12T14:00:59Z",
              "event_type":             "api",
              "base_commit":            nil,
              "head_commit":            nil
            }.to_json
          ]
        end
      end
    end

    it 'returns the raw response' do
      expect(subject.run(repo: 'kale')).to respond_to(:body)
    end
  end
end
