# syntax=docker/dockerfile:1
# Imagem do Console do Dono (ASP.NET Core MVC). Contexto: raiz do repositório.
#   docker build -f admin-mvc/Dockerfile -t techcare-console .

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY admin-mvc/TechCare.Admin.csproj admin-mvc/
RUN dotnet restore admin-mvc/TechCare.Admin.csproj
COPY admin-mvc/ admin-mvc/
RUN dotnet publish admin-mvc/TechCare.Admin.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "TechCare.Admin.dll"]
