#!/usr/bin/env groovy

REPOSITORY = 'whitehall'
DEFAULT_SCHEMA_BRANCH = 'deployed-to-production'

node {
  def govuk = load '/var/lib/jenkins/groovy_scripts/govuk_jenkinslib.groovy'

  govuk.buildProject(
    sassLint: false,
    beforeTest: {
      stage("Generate directories for upload tests") {
        sh ("mkdir -p ./incoming-uploads")
        sh ("mkdir -p ./clean-uploads")
        sh ("mkdir -p ./infected-uploads")
        sh ("mkdir -p ./attachment-cache")
      }
    },
    overrideTestTask: {
      lock ("whitehall-$NODE_NAME-test") {
        stage("Set up the DB") {
          sh("RAILS_ENV=test bundle exec rake db:drop db:create db:schema:load")
        }

        stage("Run tests") {
          govuk.setEnvar("RAILS_ENV", "test")
          if (params.IS_SCHEMA_TEST) {
            echo "Running a subset of the tests to check the content schema changes"
            govuk.runRakeTask("test:publishing_schemas --trace")
          } else {
            govuk.runRakeTask("ci:setup:minitest test:in_parallel --trace")
          }
        }
      }
    },
  )
}
