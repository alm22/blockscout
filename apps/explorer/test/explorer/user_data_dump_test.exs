defmodule Explorer.UserDataDumpTest do
  use Explorer.DataCase

  alias Plug.Conn

  describe "generate_dump/0" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:ex_aws, :host, "localhost")
      Application.put_env(:ex_aws, :retries, max_attempts: 1)
      Application.put_env(:ex_aws, :s3, scheme: "http://", host: "localhost", port: bypass.port)

      {:ok, bypass: bypass}
    end

    test "return {:ok, :done} when request status is 200", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.resp(200, upload_response_body())
      end)

      assert {:ok, :done} = Explorer.UserDataDump.generate_dump()
    end

    test "return {:error, etag} when request status is a failure code", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.resp(500, upload_response_body())
      end)

      assert {:error, _} = Explorer.UserDataDump.generate_dump()
    end

    test "delete temporary dump file after a success", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.resp(200, upload_response_body())
      end)

      Explorer.UserDataDump.generate_dump()
      refute File.exists?("/temp/address_names.csv")
      refute File.exists?("/temp/smart_contracts.csv")
    end

    test "delete temporary dump file after an error", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.resp(500, upload_response_body())
      end)

      Explorer.UserDataDump.generate_dump()
      refute File.exists?("/temp/address_names.csv")
      refute File.exists?("/temp/smart_contracts.csv")
    end
  end

  describe "restore_from_dump/0" do
    setup do
      bypass = Bypass.open()

      Application.put_env(:ex_aws, :host, "localhost")
      Application.put_env(:ex_aws, :s3, scheme: "http://", host: "localhost", port: bypass.port)

      {:ok, bypass: bypass}
    end

    test "return {:ok, done} when the restoring works", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.update_resp_header("Content-Length", "0", fn a -> a || "0" end)
        |> Conn.resp(200, "")
      end)

      assert {:ok, :done} = Explorer.UserDataDump.restore_from_dump()
    end

    test "return {:error, error message} if the request fails", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.update_resp_header("Content-Length", "0", fn a -> a || "0" end)
        |> Conn.resp(500, "")
      end)

      assert {:error, _} = Explorer.UserDataDump.restore_from_dump()
    end

    test "erase downloaded file after restoring", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.update_resp_header("Content-Length", "0", fn a -> a || "0" end)
        |> Conn.resp(200, "")
      end)

      Explorer.UserDataDump.restore_from_dump()
      refute File.exists?("/temp/address_names.csv")
      refute File.exists?("/temp/smart_contracts.csv")
    end

    test "erase download files if things go wrong", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Conn.update_resp_header("etag", "etag", fn a -> a || "etag" end)
        |> Conn.update_resp_header("Content-Length", "0", fn a -> a || "0" end)
        |> Conn.resp(500, "")
      end)

      Explorer.UserDataDump.restore_from_dump()
      refute File.exists?("/temp/address_names.csv")
      refute File.exists?("/temp/smart_contracts.csv")
    end
  end

  defp upload_response_body() do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <Bucket>somebucket</Bucket>
    <Key>abcd</Key>
    <UploadId>bUCMhxUCGCA0GiTAhTj6cq2rChItfIMYBgO7To9yiuUyDk4CWqhtHPx8cGkgjzyavE2aW6HvhQgu9pvDB3.oX73RC7N3zM9dSU3mecTndVRHQLJCAsySsT6lXRd2Id2a</UploadId>
    <ETag>&quot;89asdfasdf0asdfasdfasd&quot;</ETag>
    </InitiateMultipartUploadResult>
    <CompleteMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/\">
    <Location>https://google.com</Location>
    <Bucket>name_of_my_bucket</Bucket>
    <Key>name_of_my_key.ext</Key>
    <ETag>&quot;89asdfasdf0asdfasdfasd&quot;</ETag>
    </CompleteMultipartUploadResult>
    <ETag>&quot;89asdfasdf0asdfasdfasd&quot;</ETag>
    """
  end
end
