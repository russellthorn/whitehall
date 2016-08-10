require 'test_helper'
require 'gds_api/test_helpers/publishing_api_v2'

class PublishingApiDocumentRepublishingWorkerTest < ActiveSupport::TestCase
  include GdsApi::TestHelpers::PublishingApiV2

  test "it pushes the published and the draft editions of a document if there is a later draft" do
    document = stub(
      published_edition: published_edition = build(:edition, id: 1),
      id: 1,
      pre_publication_edition: draft_edition = build(:edition, id: 2),
    )

    Document.stubs(:find).returns(document)

    PublishingApiWorker.expects(:new).returns(api_worker = mock)
    api_worker.expects(:perform).with(published_edition.class.name, published_edition.id, "republish", "en")

    PublishingApiDraftWorker.expects(:new).returns(draft_worker = mock)
    draft_worker.expects(:perform).with(draft_edition.class.name, draft_edition.id, "republish", "en")

    PublishingApiDocumentRepublishingWorker.new.perform(document.id)
  end

  class PublishException < StandardError; end
  class DraftException < StandardError; end
  test "it pushes the published version first if there is a more recent draft" do
    document = stub(
      published_edition: build(:edition),
      id: 1,
      pre_publication_edition: build(:edition),
    )

    Document.stubs(:find).returns(document)

    PublishingApiWorker.stubs(:new).returns(api_worker = mock)
    api_worker.stubs(:perform).raises(PublishException)
    PublishingApiDraftWorker.stubs(:new).returns(draft_worker = mock)
    draft_worker.stubs(:perform).raises(DraftException)

    assert_raises PublishException do
      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end
  end

  test "it pushes all locales for the published document" do
    document  = create(:document, content_id: SecureRandom.uuid)
    edition = build(:published_edition, title: "Published edition", document: document)
    with_locale(:es) { edition.title = "spanish-title" }
    edition.save!

    presenter = PublishingApiPresenters.presenter_for(edition, update_type: 'republish')
    requests = [
      stub_publishing_api_put_content(document.content_id, with_locale(:en) { presenter.content }),
      stub_publishing_api_publish(document.content_id, locale: 'en', update_type: 'republish'),
      stub_publishing_api_put_content(document.content_id, with_locale(:es) { presenter.content }),
      stub_publishing_api_publish(document.content_id, locale: 'es', update_type: 'republish')
    ]
    # Have to separate this as we need to manually assert it was done twice. If
    # we split the pushing of links into a separate job, then we would only push
    # links once and could put this back into the array.
    patch_links_request = stub_publishing_api_patch_links(document.content_id, links: presenter.links)

    PublishingApiDocumentRepublishingWorker.new.perform(document.id)

    assert_all_requested(requests)
    assert_requested(patch_links_request, times: 2)
  end

  test "it runs the PublishingApiUnpublishingWorker if the latest edition
    has an unpublishing" do
    document  = create(:document, content_id: SecureRandom.uuid)
    edition = create(:unpublished_edition, title: "Unpublished edition", document: document)
    unpublishing = edition.unpublishing

    PublishingApiUnpublishingWorker.expects(:new).returns(worker_instance = mock)
    worker_instance.expects(:perform).with(unpublishing.id, true)

    PublishingApiDocumentRepublishingWorker.new.perform(document.id)
  end

  test "it supports jobs with the old method signature" do
    document  = create(:document, content_id: SecureRandom.uuid)
    edition = create(:published_edition, title: "Published edition", document: document)

    real_worker = PublishingApiDocumentRepublishingWorker.new

    PublishingApiDocumentRepublishingWorker
      .expects(:new).returns(worker = mock)
    worker.expects(:perform)
      .with(document.id)

    real_worker.perform(edition.id, nil)
  end
end
