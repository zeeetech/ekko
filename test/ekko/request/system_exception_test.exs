defmodule Ekko.Request.SystemExceptionTest do
  use ExUnit.Case, async: true

  alias Ekko.Request
  alias Ekko.Request.SystemException
  alias Ekko.Test.Fixtures

  describe "from_map/1" do
    test "parses error and cause" do
      raw = %{
        "type" => "System.ExceptionEncountered",
        "requestId" => "req-exc-1",
        "timestamp" => "2026-04-09T10:00:00Z",
        "locale" => "en-US",
        "error" => %{
          "type" => "INVALID_RESPONSE",
          "message" => "Something broke"
        },
        "cause" => %{
          "requestId" => "req-prev-1"
        }
      }

      assert {:ok, %SystemException{} = se} = SystemException.from_map(raw)
      assert se.error.type == "INVALID_RESPONSE"
      assert se.error.message == "Something broke"
      assert se.cause.request_id == "req-prev-1"
      assert se.locale == "en-US"
    end

    test "tolerates missing cause" do
      raw = %{
        "type" => "System.ExceptionEncountered",
        "requestId" => "req-exc-2",
        "timestamp" => "2026-04-09T10:00:00Z",
        "error" => %{
          "type" => "INTERNAL_SERVICE_ERROR",
          "message" => "Internal error"
        }
      }

      assert {:ok, %SystemException{cause: nil}} = SystemException.from_map(raw)
    end

    test "rejects missing error payload" do
      raw = %{
        "type" => "System.ExceptionEncountered",
        "requestId" => "req-exc-3",
        "timestamp" => "2026-04-09T10:00:00Z"
      }

      assert {:error, _} = SystemException.from_map(raw)
    end
  end

  describe "Request.from_map/1 dispatch" do
    test "dispatches System.ExceptionEncountered" do
      assert {:ok, %Request{request: %SystemException{}}} =
               Request.from_map(Fixtures.system_exception_encountered())
    end
  end
end
