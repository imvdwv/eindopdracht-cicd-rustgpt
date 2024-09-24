# Gebruikt de officiële Rust image (Best Practice 1: Gebruik officiële images)
# Pint de versie voor meer controle en voorspelbaarheid (Best Practice 2: Pin Docker image versies)
# Gebruikt een kleinere base image voor de build-omgeving (Best Practice 4: Minimaliseer image grootte tijdens build)
FROM rust:1.81.0-slim AS builder

# Het gebruik van de WORKDIR- en ENV-instructies minimaliseert lagen en maakt de Dockerfile efficiënter (Best Practice 4: Minimaliseer image grootte tijdens build)
WORKDIR /app

# Omgevingsvariabelen worden gebruikt, maar niet voor gevoelige gegevens zoals wachtwoorden (Best Practice 7 kan hier beter geïmplementeerd worden)
ENV MIGRATIONS_PATH=db/migrations        
ENV TEMPLATES_PATH=templates             
ENV DATABASE_URL=sqlite:db/db.db         
ENV DATABASE_PATH=db/db.db               

# Minimaliseer het aantal COPY-opdrachten door meerdere bestanden in één keer te kopiëren (Best Practice 4: Minimaliseer lagen)
# Zorgt ervoor dat gevoelige data op een veilige manier wordt behandeld. (Best Practice 7 kan hier beter geïmplementeerd worden)
COPY db/migrations ./db/migrations    
COPY seeds ./seeds                    
COPY src ./src                        
COPY templates ./templates            
COPY agg.bash Cargo.lock Cargo.toml flake.lock flake.nix justfile rust-toolchain.toml tailwind.config.js .envrc .gitignore test.json .
COPY input.css ./assets/input.css      

# Door specifieke versies van softwarepakketten te definiëren; voorkomt dat Docker build breekt door onverwachte wijzigingen (Best Practice 2: Pin Docker image versies)
# Gebruikt ENV i.p.v. RUN of een meer complexe manier om versies op te halen; voorkomt extra lagen in de Dockerfile (Best Practice 4: Minimaliseer image grootte tijdens build)
ENV TAILWIND_VERSION=3.4.11   
ENV JUST_VERSION=1.35.0      

# Vermijdt caching, combineert meerdere commando's, minimaliseert onnodige bestanden om de image-grootte te verkleinen. (Best Practice 4: Minimaliseer image grootte tijdens build)
RUN apt-get update && apt-get install -y --no-install-recommends curl pkg-config libssl-dev \
  && curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/download/v$TAILWIND_VERSION/tailwindcss-linux-x64 \
  && chmod +x tailwindcss-linux-x64 && mv tailwindcss-linux-x64 /usr/local/bin/tailwindcss \
  && cargo install just --version $JUST_VERSION \
  && tailwindcss -i ./assets/input.css -o ./assets/output.css --minify \
  && just init && cargo build --release \
  && rm -rf /var/lib/apt/lists/* /app/target/release/deps/*.d /app/target/release/.fingerprint \
  && ls -lh /app/target/release

# Gebruikt de officiële ubuntu image (Best Practice 1: Gebruik officiële images)
# Pint de versie voor meer controle en voorspelbaarheid (Best Practice 2: Pin Docker image versies)
# Gebruik een kleinere base image voor productie (Best Practice 4: Minimaliseer image grootte en lagen)
FROM ubuntu:22.04

WORKDIR /app              

# Minimaliseer het aantal COPY-opdrachten door meerdere bestanden in één keer te kopiëren (Best Practice 4: Minimaliseer lagen)
# Zorgt ervoor dat gevoelige data op een veilige manier wordt behandeld. (Best Practice 7 kan hier beter geïmplementeerd worden)
ENV MIGRATIONS_PATH=db/migrations        
ENV TEMPLATES_PATH=templates             
ENV DATABASE_URL=sqlite:db/db.db         
ENV DATABASE_PATH=db/db.db               

# Zorgt ervoor dat de meest recente pakketten worden geïnstalleerd (Best Practice 3: Houd Docker en de host up‐to‐date)
# Verwijder je de ongebruikte apt-cache en verklein je de grootte van de image (Best Practice 4: Minimaliseer image grootte tijdens build)
RUN apt-get update && apt-get install -y --no-install-recommends libssl3 \
  && rm -rf /var/lib/apt/lists/*  

# Kopieert alleen noodzakelijke bestanden van de build image (Best Practice 4: Minimaliseer image grootte tijdens build)
COPY --from=builder /app/target/release/rustgpt /app/rustgpt
COPY --from=builder /app/templates /app/templates   
COPY --from=builder /app/db /app/db                 
COPY --from=builder /app/assets/output.css /app/assets/output.css

# Toevoegen van een nieuwe niet-rootgebruiker en beperkt privileges door alleen noodzakelijke uitvoerrechten te geven (Best Practice 5: Beperk privileges en toegang)
# Draait Docker in rootless mode door een niet-root gebruiker te creëren en over te schakelen naar deze gebruiker (Best Practice 11: Draai Docker in rootless mode)
RUN groupadd -r myuser && useradd -r -g myuser myuser \
  && chown -R myuser:myuser /app \
  && chmod +x /app/rustgpt

# Zet de user naar de niet-root gebruiker (Best Practice 5: Beperk privileges en toegang)
USER myuser

# Het exposen van poorten helpt bij het segmenteren en beperken van netwerkverkeer (Best Practice 6: Implementeer netwerksegmentatie)
EXPOSE 3000

# Stuurt logs naar stdout/stderr, zodat Docker ze kan verzamelen en monitoren (Best Practice 14: Verzamel en monitor Docker logs)
CMD ["/app/rustgpt"] 