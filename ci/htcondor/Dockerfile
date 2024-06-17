FROM  htcondor/submit:el7 as submit

RUN curl -o miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash miniconda.sh -f -b -p /opt/anaconda && \
    /opt/anaconda/bin/conda clean -tipy && \
    rm -f miniconda.sh
ENV PATH /opt/anaconda/bin:$PATH
# environment.yml file is copied by CI script. If manually building, you should copy it too from parent directory
COPY environment.yml .
RUN conda env update -n base --file environment.yml

FROM  htcondor/execute:el7 as execute

COPY --from=submit /opt/anaconda /opt/anaconda
ENV PATH /opt/anaconda/bin:$PATH
