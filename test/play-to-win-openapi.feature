Feature: Kogito Serverless workflow - Play To Win

  Background:
    Given HTTP server timeout is 15000 ms
    Given OpenAPI server timeout is 15000 ms
    Given Knative event consumer timeout is 20000 ms

  Scenario: Create supporting services
    # Verify Knative broker
    Given create Knative broker default
    Given Knative broker default is running

    # Create Http server
    Given HTTP server "kogito-test"
    Given create Kubernetes service kogito-test

    # Create prize event consumer service
    Given Knative service port 8081
    Given create Knative event consumer service prize-service
    Given create Knative trigger prize-service-trigger on service prize-service with filter on attributes
      | type   | prizes |

  Scenario: User wins a prize
    Given variable name is "krisv"

    # Create new participant event
    Given Knative event data: {"username": "${name}"}
    Then send Knative event
      | type            | participants |
      | source          | /test/participant |
      | subject         | New participant |
      | id              | citrus:randomUUID() |

    # Verify score service called
    Given HTTP server "kogito-test"
    Given OpenAPI service "kogito-test"
    Given OpenAPI specification: score.yaml
    Given OpenAPI outbound dictionary
    | $.result | true |
    When verify operation: isWinner
    Then send operation response: 200

    # Verify get employee details service called
    Given OpenAPI specification: employee.yaml
    When verify operation: getEmployeeDetails
    Then send operation response: 200

    # Verify prize won event
    Given Knative service "prize-service"
    Then expect Knative event data
    """
      {
        "username": "${name}",
        "result": true,
        "firstName": "@notEmpty()@",
        "lastName":"@notEmpty()@",
        "address":"@notEmpty()@",
        "prize": "Lego Mindstorms"
      }
    """
    And verify Knative event
      | id              | @ignore@ |
      | type            | prizes |
      | source          | /process/PlayToWin_ServerlessWorkflow |

  Scenario: Remove resources
    Given delete Kubernetes service prize-service
    Given delete Kubernetes service kogito-test
