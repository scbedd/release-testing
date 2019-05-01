pip install setuptools 
pip install wheel twine readme-renderer[md]

cd C:/checks
mkdir sdk-for-js
mkdir sdk-for-python
mkdir sdk-for-java
mkdir sdk-for-net

git clone https://github.com/Azure/azure-sdk-for-java.git sdk-for-java
git clone https://github.com/Azure/azure-sdk-for-python.git sdk-for-python
git clone https://github.com/Azure/azure-sdk-for-js.git sdk-for-js
git clone https://github.com/Azure/azure-sdk-for-net.git sdk-for-net

pip install "C:\projects\publish\warden\doc_warden-0.3.0-py2.py3-none-any.whl"

ward scan -d C:/checks/sdk-for-java  -c C:/checks/sdk-for-java/eng/.docsettings.yml 
ward scan -d C:/checks/sdk-for-net  -c C:/checks/sdk-for-net/eng/.docsettings.yml 
ward scan -d C:/checks/sdk-for-python 
ward scan -d C:/checks/sdk-for-js 
