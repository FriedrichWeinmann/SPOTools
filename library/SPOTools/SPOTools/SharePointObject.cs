using System;
using System.Collections.Generic;
using System.Drawing.Text;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Microsoft.SharePoint.Client;
using PSFramework.Utility;

namespace SPOTools
{
    public class SharePointObject
    {
        public ClientObject InputObject;
        private PSObject _PSInputObject;
        public SharePointObjectType Type;
        public string Name
        {
            get { return (string)_PSInputObject.Properties["Name"].Value; }
        }
        public string HostName
        {
            get
            {
                if (String.IsNullOrEmpty(_HostName))
                    _HostName = Regex.Replace(InputObject.Context.Url, "https://(.+?)/.+$", "$1");
                return _HostName;
            }
        }
        private string _HostName;
        public string SiteName
        {
            get
            {
                if (String.IsNullOrEmpty(_SiteName))
                    _SiteName = Regex.Replace(InputObject.Context.Url, "https://.+?/sites/(.+?)(/.+){0,}$", "$1").Trim('/');
                return _SiteName;
            }
        }
        private string _SiteName;
        public string HostPath
        {
            get
            {
                if (!String.IsNullOrEmpty(_HostPath))
                    return _HostPath;

                string corePath = Regex.Split((PSObject.AsPSObject(_PSInputObject.Properties["Path"]).Properties["Identity"].Value as string), ":file:|:folder:").Last();
                if (_PSInputObject.Properties.Where(o => o.Name == "ServerRelativeUrl").Count() > 0 && !String.IsNullOrEmpty(_PSInputObject.Properties["ServerRelativeUrl"].Value as string))
                    _HostPath = $"https://{HostName}{_PSInputObject.Properties["ServerRelativeUrl"].Value}";
                else if (UtilityHost.IsLike(corePath, "/sites/*/https://*.sharepoint.com/sites*"))
                    _HostPath = Regex.Replace(corePath, "^.+?(https://.+)$", "$1", RegexOptions.IgnoreCase);
                else
                    _HostPath = $"https://{HostPath}{corePath}";

                return _HostPath;
            }
        }
        private string _HostPath;
        public string ServerRelativePath
        {
            get
            {
                if (String.IsNullOrEmpty(_ServerRelativePath))
                    _ServerRelativePath = Regex.Replace(HostPath, "^https://.+?/", "/");
                return _ServerRelativePath;
            }
        }
        private string _ServerRelativePath;
        public string SiteRelativePath
        {
            get
            {
                if (String.IsNullOrEmpty(_SiteRelativePath))
                    _SiteRelativePath = Regex.Replace(ServerRelativePath, "^/sites/.+?/", "");
                return _SiteRelativePath;
            }
        }
        private string _SiteRelativePath;
        public string Parent
        {
            get
            {
                if (String.IsNullOrEmpty(_Parent))
                    _Parent = Regex.Replace(SiteRelativePath, "(.+)/.+", "$1");
                return _Parent;
            }
        }
        private string _Parent;

        public SharePointObject(ClientObject SharepointItem)
        {
            if (null == SharepointItem)
                throw new ArgumentNullException("SharepointItem", "The input object cannot be null!");

            Type = ResolveType(SharepointItem);
            InputObject = SharepointItem;
            _PSInputObject = PSObject.AsPSObject(SharepointItem);
        }

        private SharePointObjectType ResolveType(ClientObject SharepointItem)
        {
            switch (SharepointItem.GetType().Name)
            {
                case "File":
                    return SharePointObjectType.File;
                case "Folder":
                    return SharePointObjectType.Folder;
                default:
                    throw new NotSupportedException($"Sharepoint object tyoe {SharepointItem.GetType().Name} is not supported!");
            }
        }
    }
}
