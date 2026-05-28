defmodule PortalWeb.Router do
  use PortalWeb, :router
  import Backpex.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :chat_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :admin do
    plug PortalWeb.Plugs.AdminAuth
  end

  scope "/", PortalWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/sitemap.xml", PageController, :sitemap
    get "/sitemap-static.xml", PageController, :sitemap_static
    get "/sitemap-companies.xml", PageController, :sitemap_companies
    get "/sitemap-location.xml", PageController, :sitemap_location_redirect
    get "/sitemap-locations.xml", PageController, :sitemap_locations
    get "/sitemap-keywords.xml", PageController, :sitemap_keywords
    get "/about", PageController, :about
    get "/how-it-works", PageController, :how_it_works
    get "/pricing", PageController, :pricing
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
    get "/status", PageController, :status
    get "/changelog", PageController, :changelog
    get "/auth/github", AuthController, :github
    get "/auth/github/callback", AuthController, :github_callback
    get "/jobs", JobController, :index
    get "/jobs/:id", JobController, :show
    get "/companies/:slug", CompanyController, :show
    post "/jobs/:id/apply", JobController, :apply
    post "/leads", LeadController, :create
    post "/logout", LeadController, :delete
  end

  scope "/", PortalWeb do
    pipe_through :chat_api

    get "/chat/config", ChatController, :config
    post "/chat/conversations", ChatController, :create_conversation
    get "/chat/messages", ChatController, :messages
    post "/chat/messages", ChatController, :create_message
  end

  scope "/", PortalWeb do
    pipe_through :api

    post "/telegram/webhook/:secret", ChatController, :telegram_webhook
  end

  scope "/admin", PortalWeb do
    pipe_through [:browser, :admin]

    get "/", AdminController, :index
    get "/crawler", AdminController, :crawler
    backpex_routes()

    live_session :admin, on_mount: Backpex.InitAssigns do
      live_resources "/leads", Admin.LeadLive
      live_resources "/job-interests", Admin.JobInterestLive, only: [:index, :show]
      live_resources "/companies", Admin.CompanyLive
      live_resources "/jobs", Admin.JobPostLive, only: [:index, :show]
      live_resources "/chat-conversations", Admin.ChatConversationLive
      live_resources "/chat-messages", Admin.ChatMessageLive, only: [:index, :show]
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", PortalWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:portal, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PortalWeb.Telemetry
    end
  end
end
