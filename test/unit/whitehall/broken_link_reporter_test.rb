require 'test_helper'
require 'gds_api/test_helpers/link_checker_api'

class BrokenLinkReporterTest < ActiveSupport::TestCase

  class EditionCheckerTest < ActiveSupport::TestCase
    include GdsApi::TestHelpers::LinkCheckerApi

    test '#page_url returns the production public page URL of the document' do
      detailed_guide = create(:detailed_guide)
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(detailed_guide)
      assert_equal "https://www.gov.uk#{Whitehall.url_maker.detailed_guide_path(detailed_guide.slug)}", checker.public_url
    end

    test '#admin_url returns the production admin URL of the document' do
      detailed_guide = create(:detailed_guide)
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(detailed_guide)

      assert_equal "https://whitehall-admin.publishing.service.gov.uk/government/admin/detailed-guides/#{detailed_guide.id}",
        checker.admin_url
    end

    test '#organisation returns the lead organisation of the document' do
      organisation   = create(:organisation)
      detailed_guide = create(:detailed_guide, lead_organisations: [organisation])
      checker        = Whitehall::BrokenLinkReporter::EditionChecker.new(detailed_guide)

      assert_equal organisation, checker.organisation
    end

    test '#organisation returns a worldwide organisation for documents that have them' do
      worldwide_organisation = create(:worldwide_organisation)
      world_news_article     = create(:world_location_news_article, worldwide_organisations: [worldwide_organisation])
      checker                = Whitehall::BrokenLinkReporter::EditionChecker.new(world_news_article)

      assert_equal worldwide_organisation, checker.organisation
    end

    test '#organisation returns the first organisation for documents that do not have any lead organisations' do
      speech = create(:speech, person_override: "The Queen", role_appointment: nil, create_default_organisation: false)
      organisation = create(:organisation)
      speech.organisations << organisation
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(speech)

      assert_equal organisation, checker.organisation
    end

    test '#organisation returns the owning organisation for a corporate information page' do
      corporate_information_page = create(:corporate_information_page)
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(corporate_information_page)

      assert_equal corporate_information_page.owning_organisation, checker.organisation
    end

    test '#timestamp returns the public_timestamp as a string' do
      edition = create(:published_edition)
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(edition)

      assert_equal edition.public_timestamp.to_s, checker.timestamp
    end

    test '#start_check checks the links of an edition' do
      detailed_guide = create(:detailed_guide,
                              body: "[good](https://www.gov.uk/good-link)")

      body = link_checker_api_batch_report_hash(
        id: 1,
        status: "completed",
        links: [{ uri: "http://www.gov.uk/good-link", status: "ok" }],
      )
      stub_request(:post, "#{Plek.find('link-checker-api')}/batch")
        .to_return(
          body: body.to_json,
          status: 201,
          headers: { "Content-Type": "application/json" },
        )
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(detailed_guide)
      checker.start_check

      assert checker.is_complete?
      assert_equal checker.broken_links, []
    end

    test '#check_progress gets the current status of the batch report' do
      detailed_guide = create(:detailed_guide,
                              body: "[good](https://www.gov.uk/good-link)")

      body = link_checker_api_batch_report_hash(
        id: 1,
        status: "in_progress",
        links: [{ uri: "http://www.gov.uk/good-link", status: "pending" }],
      )
      stub_request(:post, "#{Plek.find('link-checker-api')}/batch")
        .to_return(
          body: body.to_json,
          status: 202,
          headers: { "Content-Type": "application/json" },
        )
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(detailed_guide)
      checker.start_check

      assert_equal checker.is_complete?, false

      body = link_checker_api_batch_report_hash(
        id: 1,
        status: "completed",
        links: [{ uri: "http://www.gov.uk/good-link", status: "ok" }],
      )
      stub_request(:get, "#{Plek.find('link-checker-api')}/batch/1")
        .to_return(
          body: body.to_json,
          status: 200,
          headers: { "Content-Type": "application/json" },
        )

      checker.check_progress

      assert checker.is_complete?
    end

    test '#broken_links_uris returns the uris of bad links for the edition' do
      detailed_guide = create(:detailed_guide,
                              body: "[good](https://www.gov.uk/good-link), [bad](https://www.gov.uk/bad-link), [ugly](https://www.gov.uk/missing-link)")

      body = link_checker_api_batch_report_hash(
        id: 1,
        status: "completed",
        links: [
          { uri: "https://www.gov.uk/good-link", status: "ok" },
          { uri: "https://www.gov.uk/bad-link", status: "broken" },
          { uri: "https://www.gov.uk/missing-link", status: "caution" },
      ],
      )
      stub_request(:post, "#{Plek.find('link-checker-api')}/batch")
        .to_return(
          body: body.to_json,
          status: 201,
          headers: { "Content-Type": "application/json" },
        )
      checker = Whitehall::BrokenLinkReporter::EditionChecker.new(detailed_guide)
      checker.start_check

      expected_broken_links = ['https://www.gov.uk/bad-link',]

      assert_equal expected_broken_links, checker.broken_link_uris
    end
  end
end
