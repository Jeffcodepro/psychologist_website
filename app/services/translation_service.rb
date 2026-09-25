require "net/http"
require "json"

class TranslationService
  API_URL = URI("https://api.openai.com/v1/responses")

  def initialize(title:, body:)
    @title = title.to_s
    @body = body.to_s
  end

  def call
    response = send_request

    unless response.is_a?(Net::HTTPSuccess)
      error = JSON.parse(response.body).dig("error", "message")

      raise StandardError,
            error.presence || "Não foi possível gerar a tradução."
    end

    response_data = JSON.parse(response.body)

    output_text = extract_output_text(response_data)

    translation = JSON.parse(clean_json(output_text))

    {
      title_en: translation.fetch("title"),
      body_en: translation.fetch("body")
    }
  rescue JSON::ParserError
    raise StandardError, "A IA retornou uma tradução em formato inválido."
  end

  private

  def send_request
    request = Net::HTTP::Post.new(API_URL)

    request["Authorization"] = "Bearer #{ENV.fetch('OPENAI_API_KEY')}"
    request["Content-Type"] = "application/json"

    request.body = {
      model: ENV.fetch(
        "OPENAI_TRANSLATION_MODEL",
        "gpt-5-nano"
      ),

      reasoning: {
        effort: "minimal"
      },

      instructions: <<~INSTRUCTIONS,
        You are a professional translator for a psychologist's website.

        Translate Brazilian Portuguese into natural professional English.

        Requirements:
        - Preserve the original meaning.
        - Do not invent information.
        - Do not add clinical claims.
        - Prefer natural professional English instead of literal translation.
        - Preserve the tone of the original text.
        - Keep terminology appropriate for psychology and corporate mental health.
        - Return only valid JSON.
        - Do not include Markdown.
        - Do not include explanations.

        Return exactly this structure:

        {
          "title": "translated title",
          "body": "translated body"
        }
      INSTRUCTIONS

      input: {
        title: @title,
        body: @body
      }.to_json
    }.to_json

    Net::HTTP.start(
      API_URL.hostname,
      API_URL.port,
      use_ssl: true
    ) do |http|
      http.request(request)
    end
  end

  def extract_output_text(response_data)
    content = response_data
      .fetch("output")
      .flat_map { |item| item["content"] || [] }
      .find { |item| item["type"] == "output_text" }

    raise StandardError, "A IA não retornou uma tradução." unless content

    content.fetch("text")
  end

  def clean_json(text)
    text
      .strip
      .sub(/\A```json\s*/i, "")
      .sub(/\A```\s*/, "")
      .sub(/\s*```\z/, "")
  end
end
