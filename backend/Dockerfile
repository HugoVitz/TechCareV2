# syntax=docker/dockerfile:1
# Imagem da API TechCare (ASP.NET Core 8). Build em múltiplos estágios:
# o SDK compila; a imagem final leva só o runtime (menor e com menos superfície de ataque).
# Contexto de build: raiz do repositório (precisa da pasta frontend/).
#   docker build -f backend/Dockerfile -t techcare-api .

FROM mcr.microsoft.com/dotnet/sdk:11.0 AS build
WORKDIR /src
# Restaura primeiro só com o .csproj: a camada de pacotes fica em cache entre builds.
COPY backend/TechCarePro.Api.csproj backend/
RUN dotnet restore backend/TechCarePro.Api.csproj
COPY backend/ backend/
RUN dotnet publish backend/TechCarePro.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
# Painel web da loja, servido pela própria API em /painel/.
COPY frontend/ ./wwwroot/painel/
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
# Usuário sem privilégios de administrador (já existe na imagem oficial do .NET 8).
USER $APP_UID
ENTRYPOINT ["dotnet", "TechCarePro.Api.dll"]
