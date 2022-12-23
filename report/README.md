# geocint status report

## will update more detials about report...

## How to install 
There are two major files app.js and index.html 
To run app.js, nodejs and npm should be installed on local machine  
If properly installed you can install http-server also to run html files easily -> sudo npm i http-server 

To run app.js, dependencies should also be installed. Dependencies are defined in package.json file.  
To install dependencies under this folder run 
npm install 

## How to run 
To start application run on terminal  
node app.js 
You have to see this log >report server is listening on port 5000 
You need also make_profile.db under report folder 
If your make_profile.db is old, change the code on app.js 
const daysBack = 15;  
I use 
const daysBack = 45;  

You can change app.js. Important parts -> application works on port 5000, you can change it on code
I check failed operation if failed.touch file exists.  
You can test it with a local file by using this code.
!First create foo.xt file under report folder 
  
if (fs.existsSync(path.join(__dirname, "foo.txt"))) { 
  instead of this 
if (fs.existsSync(failedFile)) {  
  
## How to reach report
Under report folder you can start a simple web server 
http-server -p 9000 
Now you have a simple web server.    
Please go to reportFiles/scripts.js file  
Chance this line with this. Actual code developed for Geocint and Stratum 
var url = "http://localhost:5000/statusReport"; 

Now go to web browser and go to http://localhost:9000/  