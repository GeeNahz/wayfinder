defmodule Wayfinder.Directory.ChurchNotifier do
  @moduledoc """
  Emails sent to a church's contact address.

  URLs are built by the web layer and passed in, so this module doesn't need
  to know about routes.
  """
  import Swoosh.Email

  alias Wayfinder.Mailer
  alias Wayfinder.Directory.Church

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Mailer.default_from())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_verification(%Church{} = church, url) do
    deliver(church.contact_email, "Confirm your church listing", """
    Hi,

    Thanks for adding #{church.name} to Wayfinder!

    Please confirm your email address by opening the link below. After that,
    our team will review the listing before it appears on the map.

    #{url}

    This link expires in 48 hours. If you didn't submit this church, you can
    ignore this email and nothing will be published.
    """)
  end

  def deliver_approved(%Church{} = church, url) do
    deliver(church.contact_email, "#{church.name} is now on Wayfinder", """
    Hi,

    Good news: #{church.name} has been approved and is now visible on Wayfinder.

    #{url}

    Need to change something later? Open the church page and choose
    "Request to edit".
    """)
  end

  def deliver_rejected(%Church{} = church) do
    deliver(church.contact_email, "About your Wayfinder listing", """
    Hi,

    Thanks for submitting #{church.name}. Unfortunately we couldn't publish it.

    Reason: #{church.rejection_reason || "No reason given."}

    You're welcome to submit it again with the details corrected.
    """)
  end

  def deliver_manage_link(%Church{} = church, url) do
    deliver(church.contact_email, "Your link to edit #{church.name}", """
    Hi,

    Your request to edit #{church.name} on Wayfinder was approved.
    Use the private link below to update the details and weekly activities:

    #{url}

    The link works for 7 days. Please don't share it: anyone with it can
    edit the listing.
    """)
  end
end
